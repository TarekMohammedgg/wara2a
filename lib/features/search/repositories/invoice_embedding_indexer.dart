import '../../../core/ai/embedding/embedding_engine.dart';
import '../../../core/ai/embedding/embedding_gemma_artifact.dart';
import '../../../core/ai/embedding/reviewed_invoice_indexer.dart';
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
}

class ReindexReport {
  const ReindexReport({
    required this.total,
    required this.indexed,
    required this.stale,
    required this.unavailable,
    required this.failed,
  });

  final int total;
  final int indexed;
  final int stale;
  final int unavailable;
  final int failed;
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

  Future<int> pendingCount() async => (await _pending()).length;

  @override
  Future<void> indexReviewedInvoice(int invoiceId) async {
    try {
      await indexInvoice(invoiceId);
    } finally {
      // Capture/review performs a one-off document embedding. Batch reindexing
      // calls indexInvoice directly so it can intentionally retain the model.
      await engine.unload();
    }
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
      final output = await engine.embedDocument(searchableText);
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
    final operation = _reindexPending(onProgress: onProgress);
    _track(operation);
    return operation;
  }

  Future<ReindexReport> _reindexPending({
    void Function(int completed, int total)? onProgress,
  }) async {
    final pending = await _pending();
    var indexed = 0;
    var stale = 0;
    var unavailable = 0;
    var failed = 0;
    for (var index = 0; index < pending.length; index++) {
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
    );
  }

  Future<List<InvoiceRecord>> _pending() => store.getPendingEmbeddings(
    modelId: EmbeddingGemmaArtifact.modelId,
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
