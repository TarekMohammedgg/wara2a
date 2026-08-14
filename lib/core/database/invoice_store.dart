import 'dart:async';
import 'dart:math' as math;

import '../../objectbox.g.dart';
import '../ai/embedding/embedding_vector_validator.dart';
import '../ai/embedding/open_router_embedding_artifact.dart';
import 'database_versions.dart';
import 'entities/invoice_entity.dart';
import 'entities/invoice_item_entity.dart';
import 'invoice_embedding_status.dart';
import 'invoice_record.dart';
import 'invoice_search_spec.dart';

class InvoiceNotFoundException implements Exception {
  const InvoiceNotFoundException(this.id);

  final int id;

  @override
  String toString() => 'Invoice $id was not found.';
}

class InvalidInvoiceWriteException implements Exception {
  const InvalidInvoiceWriteException(this.message);

  final String message;

  @override
  String toString() => message;
}

class InvoiceStore {
  InvoiceStore(this.store);

  final Store store;

  Future<int> save(InvoiceWrite write) =>
      store.runInTransactionAsync(TxMode.write, _saveInvoice, write);

  Future<InvoiceRecord?> get(int id) =>
      store.runInTransactionAsync(TxMode.read, _getInvoice, id);

  Future<List<InvoiceRecord>> getAll() =>
      store.runInTransactionAsync(TxMode.read, _getAllInvoices, null);

  Future<List<InvoiceSearchHit>> searchExactKeywords(
    InvoiceKeywordQuery query,
  ) => store.runInTransactionAsync(TxMode.read, _searchExactKeywords, query);

  Future<List<InvoiceSearchHit>> searchFiltered(
    InvoiceSearchFilter filter, {
    int limit = 50,
  }) => store.runInTransactionAsync(
    TxMode.read,
    _searchFiltered,
    _FilteredInvoiceQuery(filter: filter, limit: limit),
  );

  Future<List<InvoiceSearchHit>> searchNearest(InvoiceVectorQuery query) =>
      store.runInTransactionAsync(TxMode.read, _searchNearest, query);

  Future<List<InvoiceRecord>> getPendingEmbeddings({
    required String modelId,
    required int searchTextSchemaVersion,
    required int embeddingSchemaVersion,
  }) => store.runInTransactionAsync(
    TxMode.read,
    _getPendingEmbeddings,
    _PendingEmbeddingQuery(
      modelId: modelId,
      searchTextSchemaVersion: searchTextSchemaVersion,
      embeddingSchemaVersion: embeddingSchemaVersion,
    ),
  );

  Future<bool> commitEmbedding(InvoiceEmbeddingCommit commit) =>
      store.runInTransactionAsync(TxMode.write, _commitEmbedding, commit);

  Future<bool> updateEmbeddingStatus(InvoiceEmbeddingStatusUpdate update) =>
      store.runInTransactionAsync(TxMode.write, _updateEmbeddingStatus, update);

  Stream<List<InvoiceRecord>> watchRecent({int limit = 20}) {
    final builder = store.box<InvoiceEntity>().query().order(
      InvoiceEntity_.updatedAt,
      flags: Order.descending,
    );
    return builder.watch(triggerImmediately: true).map((query) {
      query.limit = limit;
      return _recordsForInvoices(store, query.find());
    });
  }

  Future<DeletedInvoiceFiles?> delete(int id) =>
      store.runInTransactionAsync(TxMode.write, _deleteInvoice, id);
}

class _PendingEmbeddingQuery {
  const _PendingEmbeddingQuery({
    required this.modelId,
    required this.searchTextSchemaVersion,
    required this.embeddingSchemaVersion,
  });

  final String modelId;
  final int searchTextSchemaVersion;
  final int embeddingSchemaVersion;
}

class _FilteredInvoiceQuery {
  const _FilteredInvoiceQuery({required this.filter, required this.limit});

  final InvoiceSearchFilter filter;
  final int limit;
}

int _saveInvoice(Store store, InvoiceWrite write) {
  final invoiceBox = store.box<InvoiceEntity>();
  final itemBox = store.box<InvoiceItemEntity>();
  final invoice = write.invoice;

  if (invoice.id != 0 && invoiceBox.get(invoice.id) == null) {
    throw InvoiceNotFoundException(invoice.id);
  }

  final invoiceId = invoiceBox.put(invoice);

  for (final item in write.items) {
    if (item.name.trim().isEmpty) {
      throw const InvalidInvoiceWriteException(
        'Invoice item names must not be empty.',
      );
    }
  }

  final oldItemsQuery = itemBox
      .query(InvoiceItemEntity_.invoiceId.equals(invoiceId))
      .build();
  try {
    itemBox.removeMany(oldItemsQuery.findIds());
  } finally {
    oldItemsQuery.close();
  }

  if (write.items.isNotEmpty) {
    for (final item in write.items) {
      item
        ..id = 0
        ..invoiceId = invoiceId;
    }
    itemBox.putMany(write.items);
  }
  return invoiceId;
}

InvoiceRecord? _getInvoice(Store store, int id) {
  final invoice = store.box<InvoiceEntity>().get(id);
  if (invoice == null) return null;
  return InvoiceRecord(invoice: invoice, items: _itemsFor(store, id));
}

List<InvoiceRecord> _getAllInvoices(Store store, void _) {
  final query = store
      .box<InvoiceEntity>()
      .query()
      .order(InvoiceEntity_.updatedAt, flags: Order.descending)
      .build();
  try {
    return _recordsForInvoices(store, query.find());
  } finally {
    query.close();
  }
}

List<InvoiceSearchHit> _searchExactKeywords(
  Store store,
  InvoiceKeywordQuery request,
) {
  _validateFilter(request.filter);
  if (request.limit <= 0) {
    throw ArgumentError.value(request.limit, 'limit', 'Must be positive.');
  }
  final tokens = <String>{};
  for (final value in request.normalizedTokens) {
    final token = value.trim();
    if (token.isEmpty || token.contains(RegExp(r'\s'))) {
      throw ArgumentError.value(
        value,
        'normalizedTokens',
        'Each keyword must be one non-empty normalized token.',
      );
    }
    tokens.add(token);
  }
  if (tokens.isEmpty) {
    throw ArgumentError.value(
      request.normalizedTokens,
      'normalizedTokens',
      'At least one normalized token is required.',
    );
  }

  Condition<InvoiceEntity>? condition = _filterCondition(request.filter);
  for (final token in tokens) {
    condition = _andCondition(
      condition,
      InvoiceEntity_.keywordText.contains(' $token ', caseSensitive: true),
    );
  }
  final builder = store
      .box<InvoiceEntity>()
      .query(condition)
      .order(InvoiceEntity_.updatedAt, flags: Order.descending);
  final query = builder.build()..limit = request.limit;
  try {
    return _recordsForInvoices(
      store,
      query.find(),
    ).map((record) => InvoiceSearchHit(record: record)).toList(growable: false);
  } finally {
    query.close();
  }
}

List<InvoiceSearchHit> _searchFiltered(
  Store store,
  _FilteredInvoiceQuery request,
) {
  _validateFilter(request.filter);
  if (request.limit <= 0) {
    throw ArgumentError.value(request.limit, 'limit', 'Must be positive.');
  }
  final builder = store
      .box<InvoiceEntity>()
      .query(_filterCondition(request.filter))
      .order(InvoiceEntity_.updatedAt, flags: Order.descending);
  final query = builder.build()..limit = request.limit;
  try {
    return _recordsForInvoices(
      store,
      query.find(),
    ).map((record) => InvoiceSearchHit(record: record)).toList(growable: false);
  } finally {
    query.close();
  }
}

List<InvoiceSearchHit> _searchNearest(Store store, InvoiceVectorQuery request) {
  _validateVectorQuery(request);
  final currentCondition = _currentVectorCondition(request);
  final metadataCondition = _filterCondition(request.filter);
  final filteredCurrentCondition = metadataCondition == null
      ? currentCondition
      : currentCondition.and(metadataCondition);

  if (request.filter.isNotEmpty && request.exactFallbackMaxCandidates > 0) {
    final filteredQuery = store
        .box<InvoiceEntity>()
        .query(filteredCurrentCondition)
        .build();
    try {
      final count = filteredQuery.count();
      if (count <= request.exactFallbackMaxCandidates) {
        return _rankExactCandidates(store, filteredQuery.find(), request);
      }
    } finally {
      filteredQuery.close();
    }
  }

  final maxResultCount = request.topK * request.oversampleFactor;
  Condition<InvoiceEntity> condition = InvoiceEntity_.embedding
      .nearestNeighborsF32(request.vector, maxResultCount)
      .and(currentCondition);
  if (metadataCondition != null) {
    condition = condition.and(metadataCondition);
  }
  final query = store.box<InvoiceEntity>().query(condition).build();
  try {
    final hits = <InvoiceSearchHit>[];
    for (final result in query.findWithScores()) {
      final invoice = result.object;
      if (!_hasCurrentValidVector(invoice, request) ||
          !_acceptDistance(result.score, request.maximumDistance)) {
        continue;
      }
      hits.add(
        InvoiceSearchHit(
          record: InvoiceRecord(
            invoice: invoice,
            items: _itemsFor(store, invoice.id),
          ),
          distance: result.score,
        ),
      );
      if (hits.length == request.topK) break;
    }
    return List.unmodifiable(hits);
  } finally {
    query.close();
  }
}

List<InvoiceSearchHit> _rankExactCandidates(
  Store store,
  List<InvoiceEntity> invoices,
  InvoiceVectorQuery request,
) {
  final hits = <InvoiceSearchHit>[];
  for (final invoice in invoices) {
    if (!_hasCurrentValidVector(invoice, request)) continue;
    final distance = _cosineDistance(request.vector, invoice.embedding!);
    if (!_acceptDistance(distance, request.maximumDistance)) continue;
    hits.add(
      InvoiceSearchHit(
        record: InvoiceRecord(
          invoice: invoice,
          items: _itemsFor(store, invoice.id),
        ),
        distance: distance,
      ),
    );
  }
  hits.sort((left, right) {
    final byDistance = left.distance!.compareTo(right.distance!);
    if (byDistance != 0) return byDistance;
    return left.record.invoice.id.compareTo(right.record.invoice.id);
  });
  return List.unmodifiable(hits.take(request.topK));
}

Condition<InvoiceEntity> _currentVectorCondition(InvoiceVectorQuery request) {
  return InvoiceEntity_.embedding
      .notNull()
      .and(
        InvoiceEntity_.embeddingStatus.equals(
          InvoiceEmbeddingStatus.ready.name,
        ),
      )
      .and(InvoiceEntity_.embeddingModelId.equals(request.modelId))
      .and(InvoiceEntity_.embeddingDimensions.equals(request.dimensions))
      .and(
        InvoiceEntity_.embeddingSchemaVersion.equals(
          request.embeddingSchemaVersion,
        ),
      )
      .and(
        InvoiceEntity_.searchTextSchemaVersion.equals(
          request.searchTextSchemaVersion,
        ),
      );
}

Condition<InvoiceEntity>? _filterCondition(InvoiceSearchFilter filter) {
  Condition<InvoiceEntity>? condition;
  final amount = filter.amount;
  if (amount != null) {
    final minimum = amount.minimumMinor;
    if (minimum != null) {
      condition = _andCondition(
        condition,
        amount.minimumInclusive
            ? InvoiceEntity_.totalMinor.greaterOrEqual(minimum)
            : InvoiceEntity_.totalMinor.greaterThan(minimum),
      );
    }
    final maximum = amount.maximumMinor;
    if (maximum != null) {
      condition = _andCondition(
        condition,
        amount.maximumInclusive
            ? InvoiceEntity_.totalMinor.lessOrEqual(maximum)
            : InvoiceEntity_.totalMinor.lessThan(maximum),
      );
    }
  }
  final purchaseDate = filter.purchaseDate;
  if (purchaseDate != null) {
    condition = _andCondition(
      condition,
      InvoiceEntity_.purchaseDate.greaterOrEqualDate(
        purchaseDate.startInclusive,
      ),
    );
    condition = _andCondition(
      condition,
      InvoiceEntity_.purchaseDate.lessThanDate(purchaseDate.endExclusive),
    );
  }
  final warrantyEndDate = filter.warrantyEndDate;
  if (warrantyEndDate != null) {
    condition = _andCondition(
      condition,
      InvoiceEntity_.warrantyEndDate.greaterOrEqualDate(
        warrantyEndDate.startInclusive,
      ),
    );
    condition = _andCondition(
      condition,
      InvoiceEntity_.warrantyEndDate.lessThanDate(warrantyEndDate.endExclusive),
    );
  }
  final currencyCode = filter.currencyCode?.trim();
  if (currencyCode != null && currencyCode.isNotEmpty) {
    condition = _andCondition(
      condition,
      InvoiceEntity_.currencyCode.equals(currencyCode.toUpperCase()),
    );
  }
  return condition;
}

Condition<InvoiceEntity> _andCondition(
  Condition<InvoiceEntity>? left,
  Condition<InvoiceEntity> right,
) => left == null ? right : left.and(right);

bool _hasCurrentValidVector(InvoiceEntity invoice, InvoiceVectorQuery request) {
  final vector = invoice.embedding;
  if (vector == null ||
      invoice.embeddingStatus != InvoiceEmbeddingStatus.ready.name ||
      invoice.embeddingModelId != request.modelId ||
      invoice.embeddingDimensions != request.dimensions ||
      invoice.embeddingSchemaVersion != request.embeddingSchemaVersion ||
      invoice.searchTextSchemaVersion != request.searchTextSchemaVersion) {
    return false;
  }
  try {
    EmbeddingVectorValidator.validateNormalized(
      vector,
      dimensions: request.dimensions,
    );
    return true;
  } on InvalidEmbeddingVector {
    return false;
  }
}

double _cosineDistance(List<double> left, List<double> right) {
  var dot = 0.0;
  var leftSquared = 0.0;
  var rightSquared = 0.0;
  for (var index = 0; index < left.length; index++) {
    dot += left[index] * right[index];
    leftSquared += left[index] * left[index];
    rightSquared += right[index] * right[index];
  }
  final denominator = math.sqrt(leftSquared) * math.sqrt(rightSquared);
  return (1 - dot / denominator).clamp(0.0, 2.0).toDouble();
}

bool _acceptDistance(double distance, double? maximumDistance) =>
    distance.isFinite &&
    distance >= 0 &&
    distance <= 2 &&
    (maximumDistance == null || distance <= maximumDistance);

void _validateVectorQuery(InvoiceVectorQuery request) {
  _validateFilter(request.filter);
  if (request.dimensions != OpenRouterEmbeddingArtifact.dimensions) {
    throw ArgumentError.value(
      request.dimensions,
      'dimensions',
      'The HNSW index requires ${OpenRouterEmbeddingArtifact.dimensions}.',
    );
  }
  EmbeddingVectorValidator.validateNormalized(
    request.vector,
    dimensions: request.dimensions,
  );
  if (request.modelId.trim().isEmpty) {
    throw ArgumentError.value(request.modelId, 'modelId', 'Must not be empty.');
  }
  if (request.searchTextSchemaVersion <= 0 ||
      request.embeddingSchemaVersion <= 0) {
    throw ArgumentError(
      'Search text and embedding schema versions must be positive.',
    );
  }
  if (request.topK <= 0) {
    throw ArgumentError.value(request.topK, 'topK', 'Must be positive.');
  }
  if (request.oversampleFactor <= 0) {
    throw ArgumentError.value(
      request.oversampleFactor,
      'oversampleFactor',
      'Must be positive.',
    );
  }
  if (request.exactFallbackMaxCandidates < 0) {
    throw ArgumentError.value(
      request.exactFallbackMaxCandidates,
      'exactFallbackMaxCandidates',
      'Must not be negative.',
    );
  }
  final maximumDistance = request.maximumDistance;
  if (maximumDistance != null &&
      (!maximumDistance.isFinite ||
          maximumDistance < 0 ||
          maximumDistance > 2)) {
    throw ArgumentError.value(
      maximumDistance,
      'maximumDistance',
      'Cosine distance must be between 0 and 2.',
    );
  }
}

void _validateFilter(InvoiceSearchFilter filter) {
  final amount = filter.amount;
  if (amount != null) {
    if (amount.minimumMinor == null && amount.maximumMinor == null) {
      throw ArgumentError('An amount filter requires at least one bound.');
    }
    if (amount.minimumMinor != null &&
        amount.maximumMinor != null &&
        (amount.minimumMinor! > amount.maximumMinor! ||
            (amount.minimumMinor == amount.maximumMinor &&
                (!amount.minimumInclusive || !amount.maximumInclusive)))) {
      throw ArgumentError('Amount bounds must describe a non-empty range.');
    }
  }
  for (final date in [filter.purchaseDate, filter.warrantyEndDate]) {
    if (date != null && !date.endExclusive.isAfter(date.startInclusive)) {
      throw ArgumentError('Date range end must be after its start.');
    }
  }
}

List<InvoiceRecord> _getPendingEmbeddings(
  Store store,
  _PendingEmbeddingQuery request,
) {
  final invoices = store
      .box<InvoiceEntity>()
      .getAll()
      .where((invoice) {
        if (invoice.embeddingStatus != InvoiceEmbeddingStatus.ready.name ||
            invoice.embeddingModelId != request.modelId ||
            invoice.embeddingDimensions !=
                OpenRouterEmbeddingArtifact.dimensions ||
            invoice.embeddingSchemaVersion != request.embeddingSchemaVersion ||
            invoice.searchTextSchemaVersion !=
                request.searchTextSchemaVersion ||
            invoice.embedding == null) {
          return true;
        }
        try {
          EmbeddingVectorValidator.validateNormalized(
            invoice.embedding!,
            dimensions: OpenRouterEmbeddingArtifact.dimensions,
          );
          return false;
        } on InvalidEmbeddingVector {
          return true;
        }
      })
      .toList(growable: false);
  invoices.sort((left, right) => left.reviewedAt.compareTo(right.reviewedAt));
  return _recordsForInvoices(store, invoices);
}

bool _commitEmbedding(Store store, InvoiceEmbeddingCommit request) {
  if (request.dimensions != OpenRouterEmbeddingArtifact.dimensions) {
    throw InvalidEmbeddingVector(
      'Only ${OpenRouterEmbeddingArtifact.dimensions}-dimensional vectors may be stored.',
    );
  }
  EmbeddingVectorValidator.validateNormalized(
    request.vector,
    dimensions: OpenRouterEmbeddingArtifact.dimensions,
  );
  if (request.modelId.trim().isEmpty || request.expectedAttemptId.isEmpty) {
    throw ArgumentError('Embedding model and attempt IDs must not be empty.');
  }
  if (request.expectedSearchTextSchemaVersion !=
          DatabaseVersions.searchTextSchema ||
      request.embeddingSchemaVersion != DatabaseVersions.embeddingSchema) {
    throw ArgumentError(
      'Only current search and embedding schemas may commit.',
    );
  }
  final box = store.box<InvoiceEntity>();
  final invoice = box.get(request.invoiceId);
  if (invoice == null ||
      invoice.embeddingStatus != InvoiceEmbeddingStatus.indexing.name ||
      invoice.embeddingAttemptId != request.expectedAttemptId ||
      invoice.searchableText != request.expectedSearchableText ||
      invoice.searchTextSchemaVersion !=
          request.expectedSearchTextSchemaVersion) {
    return false;
  }
  invoice
    ..embedding = List<double>.of(request.vector, growable: false)
    ..embeddingModelId = request.modelId
    ..embeddingDimensions = request.dimensions
    ..embeddingStatus = InvoiceEmbeddingStatus.ready.name
    ..embeddingSchemaVersion = request.embeddingSchemaVersion
    ..embeddingUpdatedAt = request.indexedAt.toUtc()
    ..embeddingFailureCode = null
    ..embeddingAttemptId = null;
  box.put(invoice);
  return true;
}

bool _updateEmbeddingStatus(Store store, InvoiceEmbeddingStatusUpdate request) {
  if (request.status == InvoiceEmbeddingStatus.ready) {
    throw ArgumentError(
      'Ready embeddings must be written through commitEmbedding().',
    );
  }
  if (request.status == InvoiceEmbeddingStatus.indexing &&
      (request.attemptId == null || request.attemptId!.isEmpty)) {
    throw ArgumentError('An indexing transition requires an attempt ID.');
  }
  if (request.status == InvoiceEmbeddingStatus.indexing &&
      request.expectedSearchTextSchemaVersion !=
          DatabaseVersions.searchTextSchema) {
    throw ArgumentError('Indexing requires the current search text schema.');
  }
  final box = store.box<InvoiceEntity>();
  final invoice = box.get(request.invoiceId);
  if (invoice == null ||
      (request.expectedSearchableText != null &&
          invoice.searchableText != request.expectedSearchableText) ||
      (request.expectedSearchTextSchemaVersion != null &&
          invoice.searchTextSchemaVersion !=
              request.expectedSearchTextSchemaVersion) ||
      (request.expectedCurrentStatus != null &&
          invoice.embeddingStatus != request.expectedCurrentStatus!.name) ||
      (request.expectedAttemptId != null &&
          invoice.embeddingAttemptId != request.expectedAttemptId)) {
    return false;
  }
  invoice
    ..embeddingStatus = request.status.name
    ..embeddingFailureCode = request.failureCode
    ..embeddingAttemptId = request.status == InvoiceEmbeddingStatus.indexing
        ? request.attemptId
        : null
    ..embedding = null
    ..embeddingModelId = null
    ..embeddingDimensions = null
    ..embeddingUpdatedAt = null;
  box.put(invoice);
  return true;
}

DeletedInvoiceFiles? _deleteInvoice(Store store, int id) {
  final invoiceBox = store.box<InvoiceEntity>();
  final invoice = invoiceBox.get(id);
  if (invoice == null) return null;

  final itemBox = store.box<InvoiceItemEntity>();
  final itemsQuery = itemBox
      .query(InvoiceItemEntity_.invoiceId.equals(id))
      .build();
  try {
    itemBox.removeMany(itemsQuery.findIds());
  } finally {
    itemsQuery.close();
  }
  invoiceBox.remove(id);
  return DeletedInvoiceFiles(
    imagePath: invoice.imagePath,
    thumbnailPath: invoice.thumbnailPath,
  );
}

List<InvoiceRecord> _recordsForInvoices(
  Store store,
  List<InvoiceEntity> invoices,
) => invoices
    .map(
      (invoice) =>
          InvoiceRecord(invoice: invoice, items: _itemsFor(store, invoice.id)),
    )
    .toList(growable: false);

List<InvoiceItemEntity> _itemsFor(Store store, int invoiceId) {
  final query = store
      .box<InvoiceItemEntity>()
      .query(InvoiceItemEntity_.invoiceId.equals(invoiceId))
      .order(InvoiceItemEntity_.id)
      .build();
  try {
    return query.find();
  } finally {
    query.close();
  }
}
