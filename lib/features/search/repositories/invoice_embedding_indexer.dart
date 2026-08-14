import '../../../core/ai/embedding/embedding_engine.dart';
import '../../../core/ai/embedding/open_router_embedding_artifact.dart';
import '../../../core/ai/embedding/reviewed_invoice_indexer.dart';
import '../../../core/ai/ai_cancellation_token.dart';
import '../../../core/database/database_versions.dart';
import '../../../core/database/invoice_embedding_status.dart';
import '../../../core/database/invoice_record.dart';
import '../../../core/database/invoice_store.dart';

enum InvoiceIndexingOutcome {
  indexed,
  stale,
  missing,
  modelUnavailable,
  inputTooLong,
  failed,
  cancelled,
}

class ReindexReport {
  const ReindexReport({
    required this.total,
    required this.indexed,
    required this.stale,
    required this.unavailable,
    required this.failed,
    required this.cancelled,
  });

  final int total;
  final int indexed;
  final int stale;
  final int unavailable;
  final int failed;
  final int cancelled;
}

class InvoiceEmbeddingIndexer implements ReviewedInvoiceIndexer {
  InvoiceEmbeddingIndexer({
    required this.store,
    required this.engine,
    DateTime Function()? now,
  }) : _now = now ?? _utcNow;

  final InvoiceStore store;
  final EmbeddingEngine engine;
  final DateTime Function() _now;
  final Set<Future<void>> _inFlight = {};
  int _attemptSequence = 0;
  int _reindexGeneration = 0;

  Future<int> pendingCount() async => (await _pending()).length;

  @override
  Future<void> indexReviewedInvoice(int invoiceId) async {
    // Keep the embedding client warm so search can embed immediately afterwards.
    // Session unload is owned by SearchResourceLifecycle / app lifecycle.
    await indexInvoice(invoiceId);
  }

  Future<InvoiceIndexingOutcome> indexInvoice(int invoiceId) {
    final operation = _indexInvoice(invoiceId);
    _track(operation);
    return operation;
  }

  Future<InvoiceIndexingOutcome> _indexInvoice(int invoiceId) async {
    final record = await store.get(invoiceId);
    if (record == null) return InvoiceIndexingOutcome.missing;
    final searchableText = record.invoice.searchableText;
    final attemptId =
        '${record.invoice.id}:${_now().microsecondsSinceEpoch}:${_attemptSequence++}';
    final began = await store.updateEmbeddingStatus(
      InvoiceEmbeddingStatusUpdate(
        invoiceId: invoiceId,
        status: InvoiceEmbeddingStatus.indexing,
        expectedSearchableText: searchableText,
        expectedSearchTextSchemaVersion: record.invoice.searchTextSchemaVersion,
        attemptId: attemptId,
      ),
    );
    if (!began) return InvoiceIndexingOutcome.stale;

    late final EmbeddingEngineSnapshot availability;
    try {
      availability = await engine.refresh();
    } on Object {
      await store.updateEmbeddingStatus(
        InvoiceEmbeddingStatusUpdate(
          invoiceId: invoiceId,
          status: InvoiceEmbeddingStatus.failed,
          expectedSearchableText: searchableText,
          expectedCurrentStatus: InvoiceEmbeddingStatus.indexing,
          expectedAttemptId: attemptId,
          failureCode: 'runtime_refresh_failed',
        ),
      );
      return InvoiceIndexingOutcome.failed;
    }
    if (!availability.canEmbed) {
      await _markUnavailable(
        invoiceId,
        searchableText,
        attemptId,
        'model_unavailable',
      );
      return InvoiceIndexingOutcome.modelUnavailable;
    }

    try {
      final output = await engine.embedDocument(
        searchableText,
        title: record.invoice.merchantNormalized,
      );
      final committed = await store.commitEmbedding(
        InvoiceEmbeddingCommit(
          invoiceId: invoiceId,
          expectedSearchableText: searchableText,
          expectedSearchTextSchemaVersion:
              record.invoice.searchTextSchemaVersion,
          expectedAttemptId: attemptId,
          vector: output.vector,
          modelId: output.modelId,
          dimensions: output.dimensions,
          embeddingSchemaVersion: output.schemaVersion,
          indexedAt: _now(),
        ),
      );
      return committed
          ? InvoiceIndexingOutcome.indexed
          : InvoiceIndexingOutcome.stale;
    } on AiCancelledException {
      await store.updateEmbeddingStatus(
        InvoiceEmbeddingStatusUpdate(
          invoiceId: invoiceId,
          status: InvoiceEmbeddingStatus.pending,
          expectedSearchableText: searchableText,
          expectedCurrentStatus: InvoiceEmbeddingStatus.indexing,
          expectedAttemptId: attemptId,
        ),
      );
      return InvoiceIndexingOutcome.cancelled;
    } on EmbeddingInputTooLongException {
      await store.updateEmbeddingStatus(
        InvoiceEmbeddingStatusUpdate(
          invoiceId: invoiceId,
          status: InvoiceEmbeddingStatus.failed,
          expectedSearchableText: searchableText,
          expectedCurrentStatus: InvoiceEmbeddingStatus.indexing,
          expectedAttemptId: attemptId,
          failureCode: 'input_too_long',
        ),
      );
      return InvoiceIndexingOutcome.inputTooLong;
    } on EmbeddingUnavailableException {
      await _markUnavailable(
        invoiceId,
        searchableText,
        attemptId,
        'model_unavailable',
      );
      return InvoiceIndexingOutcome.modelUnavailable;
    } on Object {
      await store.updateEmbeddingStatus(
        InvoiceEmbeddingStatusUpdate(
          invoiceId: invoiceId,
          status: InvoiceEmbeddingStatus.failed,
          expectedSearchableText: searchableText,
          expectedCurrentStatus: InvoiceEmbeddingStatus.indexing,
          expectedAttemptId: attemptId,
          failureCode: 'embedding_failed',
        ),
      );
      return InvoiceIndexingOutcome.failed;
    }
  }

  Future<ReindexReport> reindexPending({
    void Function(int completed, int total)? onProgress,
  }) {
    final generation = ++_reindexGeneration;
    final operation = _reindexPending(
      generation: generation,
      onProgress: onProgress,
    );
    _track(operation);
    return operation;
  }

  Future<ReindexReport> _reindexPending({
    required int generation,
    void Function(int completed, int total)? onProgress,
  }) async {
    final pending = await _pending();
    var indexed = 0;
    var stale = 0;
    var unavailable = 0;
    var failed = 0;
    var cancelled = 0;
    indexing:
    for (var index = 0; index < pending.length; index++) {
      if (generation != _reindexGeneration) {
        cancelled += pending.length - index;
        break;
      }
      final outcome = await indexInvoice(pending[index].invoice.id);
      switch (outcome) {
        case InvoiceIndexingOutcome.indexed:
          indexed++;
          break;
        case InvoiceIndexingOutcome.stale:
          stale++;
          break;
        case InvoiceIndexingOutcome.modelUnavailable:
          unavailable++;
          break;
        case InvoiceIndexingOutcome.inputTooLong:
        case InvoiceIndexingOutcome.failed:
          failed++;
          break;
        case InvoiceIndexingOutcome.cancelled:
          cancelled += pending.length - index;
          break indexing;
        case InvoiceIndexingOutcome.missing:
          stale++;
          break;
      }
      onProgress?.call(index + 1, pending.length);
      if (outcome == InvoiceIndexingOutcome.modelUnavailable) {
        unavailable += pending.length - index - 1;
        break;
      }
    }
    return ReindexReport(
      total: pending.length,
      indexed: indexed,
      stale: stale,
      unavailable: unavailable,
      failed: failed,
      cancelled: cancelled,
    );
  }

  Future<void> cancelReindex() async {
    _reindexGeneration++;
    await engine.cancel();
  }

  Future<List<InvoiceRecord>> _pending() => store.getPendingEmbeddings(
    modelId: OpenRouterEmbeddingArtifact.modelId,
    searchTextSchemaVersion: DatabaseVersions.searchTextSchema,
    embeddingSchemaVersion: DatabaseVersions.embeddingSchema,
  );

  Future<void> waitForIdle() async {
    while (_inFlight.isNotEmpty) {
      await Future.wait(List<Future<void>>.of(_inFlight));
    }
  }

  void _track<T>(Future<T> operation) {
    late final Future<void> tracked;
    tracked = operation
        .then<void>((_) {}, onError: (Object _, StackTrace _) {})
        .whenComplete(() => _inFlight.remove(tracked));
    _inFlight.add(tracked);
  }

  Future<void> _markUnavailable(
    int invoiceId,
    String searchableText,
    String attemptId,
    String code,
  ) async {
    await store.updateEmbeddingStatus(
      InvoiceEmbeddingStatusUpdate(
        invoiceId: invoiceId,
        status: InvoiceEmbeddingStatus.unavailable,
        expectedSearchableText: searchableText,
        expectedCurrentStatus: InvoiceEmbeddingStatus.indexing,
        expectedAttemptId: attemptId,
        failureCode: code,
      ),
    );
  }
}

DateTime _utcNow() => DateTime.now().toUtc();
