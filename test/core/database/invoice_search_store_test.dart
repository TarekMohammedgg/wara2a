import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:wara2a/core/database/entities/invoice_entity.dart';
import 'package:wara2a/core/database/entities/invoice_item_entity.dart';
import 'package:wara2a/core/database/invoice_embedding_status.dart';
import 'package:wara2a/core/database/invoice_record.dart';
import 'package:wara2a/core/database/invoice_search_spec.dart';
import 'package:wara2a/core/database/objectbox_database.dart';
import 'package:wara2a/core/utils/document_type_normalization.dart';

const _modelId = 'test/embedding-model@1';
const _searchSchema = 2;
const _embeddingSchema = 2;
const _dimensions = 768;

void main() {
  late Directory directory;
  late ObjectBoxDatabase database;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('wara2a_search_store_');
    database = await ObjectBoxDatabase.open(directory: directory.path);
  });

  tearDown(() async {
    database.close();
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  test(
    'exact keyword tokens are boundary-safe and combine with filters',
    () async {
      final a5 = await _save(
        database,
        merchant: 'متجر A5',
        keywordText: ' samsung a5 ',
        totalMinor: 1500000,
        currencyCode: 'EGP',
        purchaseDate: DateTime.utc(2026, 8, 5),
        warrantyEndDate: DateTime.utc(2026, 9, 1),
        documentType: 'فاتورة شراء',
      );
      await _save(
        database,
        merchant: 'متجر A56',
        keywordText: ' samsung a56 ',
        totalMinor: 2500000,
        currencyCode: 'EGP',
        purchaseDate: DateTime.utc(2026, 8, 6),
        warrantyEndDate: DateTime.utc(2026, 9, 2),
        documentType: 'فاتورة شراء',
      );

      final results = await database.invoices.searchExactKeywords(
        InvoiceKeywordQuery(
          normalizedTokens: const ['samsung', 'a5'],
          filter: InvoiceSearchFilter(
            amount: const InvoiceAmountFilter(minimumMinor: 1000000),
            purchaseDate: InvoiceDateFilter(
              startInclusive: DateTime.utc(2026, 8),
              endExclusive: DateTime.utc(2026, 9),
            ),
            warrantyEndDate: InvoiceDateFilter(
              startInclusive: DateTime.utc(2026, 9),
              endExclusive: DateTime.utc(2026, 10),
            ),
            currencyCode: 'egp',
            documentType: DocumentTypeNormalization.purchaseInvoice,
          ),
        ),
      );

      expect(results.map((hit) => hit.record.invoice.id), [a5]);
      expect(results.single.distance, isNull);
      expect(results.single.record.items.single.name, 'Samsung A5');
    },
  );

  test(
    'structured filters use inclusive amounts and half-open dates',
    () async {
      final matching = await _save(
        database,
        merchant: 'مطابق',
        keywordText: ' مطابق ',
        totalMinor: 10000,
        currencyCode: 'EGP',
        purchaseDate: DateTime.utc(2026, 8, 31, 23, 59),
        warrantyEndDate: DateTime.utc(2026, 9, 30, 23, 59),
        documentType: 'فاتورة شراء',
      );
      await _save(
        database,
        merchant: 'خارج المدى',
        keywordText: ' خارج ',
        totalMinor: 9999,
        currencyCode: 'EGP',
        purchaseDate: DateTime.utc(2026, 9),
        warrantyEndDate: DateTime.utc(2026, 10),
        documentType: 'فاتورة شراء',
      );

      final results = await database.invoices.searchFiltered(
        InvoiceSearchFilter(
          amount: const InvoiceAmountFilter(minimumMinor: 10000),
          purchaseDate: InvoiceDateFilter(
            startInclusive: DateTime.utc(2026, 8),
            endExclusive: DateTime.utc(2026, 9),
          ),
          warrantyEndDate: InvoiceDateFilter(
            startInclusive: DateTime.utc(2026, 9),
            endExclusive: DateTime.utc(2026, 10),
          ),
          currencyCode: 'EGP',
        ),
      );

      expect(results.map((hit) => hit.record.invoice.id), [matching]);
    },
  );

  test(
    'HNSW returns ascending cosine distance and excludes stale vectors',
    () async {
      final exact = await _save(
        database,
        merchant: 'exact',
        keywordText: ' exact ',
        vector: _basis(0),
        embeddingStatus: InvoiceEmbeddingStatus.ready,
      );
      final orthogonal = await _save(
        database,
        merchant: 'orthogonal',
        keywordText: ' orthogonal ',
        vector: _basis(1),
        embeddingStatus: InvoiceEmbeddingStatus.ready,
      );
      await _save(
        database,
        merchant: 'pending',
        keywordText: ' pending ',
        vector: _basis(0),
        embeddingStatus: InvoiceEmbeddingStatus.pending,
      );
      await _save(
        database,
        merchant: 'old model',
        keywordText: ' old ',
        vector: _basis(0),
        embeddingStatus: InvoiceEmbeddingStatus.ready,
        embeddingModelId: 'test/old-model',
      );
      await _save(database, merchant: 'missing', keywordText: ' missing ');

      final results = await database.invoices.searchNearest(
        _vectorQuery(_basis(0), topK: 2),
      );

      expect(results.map((hit) => hit.record.invoice.id), [exact, orthogonal]);
      expect(results[0].distance, closeTo(0, 1e-5));
      expect(results[1].distance, closeTo(1, 1e-5));
    },
  );

  test(
    'selective metadata filters use exact cosine ranking and threshold',
    () async {
      await _save(
        database,
        merchant: 'closer but filtered out',
        keywordText: ' usd ',
        currencyCode: 'USD',
        vector: _basis(0),
        embeddingStatus: InvoiceEmbeddingStatus.ready,
      );
      final diagonal = await _save(
        database,
        merchant: 'diagonal',
        keywordText: ' diagonal ',
        currencyCode: 'EGP',
        vector: _normalized([1, 1]),
        embeddingStatus: InvoiceEmbeddingStatus.ready,
      );
      await _save(
        database,
        merchant: 'orthogonal',
        keywordText: ' orthogonal ',
        currencyCode: 'EGP',
        vector: _basis(1),
        embeddingStatus: InvoiceEmbeddingStatus.ready,
      );

      final results = await database.invoices.searchNearest(
        _vectorQuery(
          _basis(0),
          filter: const InvoiceSearchFilter(currencyCode: 'EGP'),
          maximumDistance: 0.5,
        ),
      );

      expect(results.map((hit) => hit.record.invoice.id), [diagonal]);
      expect(results.single.distance, closeTo(1 - 1 / math.sqrt(2), 1e-5));
    },
  );

  test('stale indexing attempts cannot clear a newer ready vector', () async {
    final id = await _save(
      database,
      merchant: 'concurrent',
      keywordText: ' concurrent ',
    );
    final record = (await database.invoices.get(id))!;

    for (final attemptId in const ['attempt-a', 'attempt-b']) {
      expect(
        await database.invoices.updateEmbeddingStatus(
          InvoiceEmbeddingStatusUpdate(
            invoiceId: id,
            status: InvoiceEmbeddingStatus.indexing,
            expectedSearchableText: record.invoice.searchableText,
            expectedSearchTextSchemaVersion: _searchSchema,
            attemptId: attemptId,
          ),
        ),
        isTrue,
      );
    }

    expect(
      await database.invoices.updateEmbeddingStatus(
        InvoiceEmbeddingStatusUpdate(
          invoiceId: id,
          status: InvoiceEmbeddingStatus.failed,
          expectedSearchableText: record.invoice.searchableText,
          expectedCurrentStatus: InvoiceEmbeddingStatus.indexing,
          expectedAttemptId: 'attempt-a',
          failureCode: 'older_failure',
        ),
      ),
      isFalse,
    );
    expect(
      await database.invoices.commitEmbedding(
        InvoiceEmbeddingCommit(
          invoiceId: id,
          expectedSearchableText: record.invoice.searchableText,
          expectedSearchTextSchemaVersion: _searchSchema,
          expectedAttemptId: 'attempt-b',
          vector: _basis(0),
          modelId: _modelId,
          dimensions: _dimensions,
          embeddingSchemaVersion: _embeddingSchema,
          indexedAt: DateTime.utc(2026, 8, 9, 1),
        ),
      ),
      isTrue,
    );
    expect(
      await database.invoices.updateEmbeddingStatus(
        InvoiceEmbeddingStatusUpdate(
          invoiceId: id,
          status: InvoiceEmbeddingStatus.failed,
          expectedSearchableText: record.invoice.searchableText,
          expectedCurrentStatus: InvoiceEmbeddingStatus.indexing,
          expectedAttemptId: 'attempt-a',
          failureCode: 'late_failure',
        ),
      ),
      isFalse,
    );

    final ready = (await database.invoices.get(id))!.invoice;
    expect(ready.embeddingStatus, InvoiceEmbeddingStatus.ready.name);
    expect(ready.embeddingAttemptId, isNull);
    expect(ready.embedding, hasLength(_dimensions));
  });

  test('metadata-filtered HNSW branch returns distances locally', () async {
    await _save(
      database,
      merchant: 'filtered-out-usd',
      keywordText: ' usd ',
      currencyCode: 'USD',
      vector: _basis(0),
      embeddingStatus: InvoiceEmbeddingStatus.ready,
    );
    final expected = await _save(
      database,
      merchant: 'kept-egp',
      keywordText: ' egp ',
      currencyCode: 'EGP',
      vector: _normalized([1, 1]),
      embeddingStatus: InvoiceEmbeddingStatus.ready,
    );

    final results = await database.invoices.searchNearest(
      _vectorQuery(
        _basis(0),
        filter: const InvoiceSearchFilter(currencyCode: 'EGP'),
        exactFallbackMaxCandidates: 0,
      ),
    );

    expect(results.map((hit) => hit.record.invoice.id), [expected]);
    expect(results.single.distance, closeTo(1 - 1 / math.sqrt(2), 1e-5));
  });
}

InvoiceVectorQuery _vectorQuery(
  List<double> vector, {
  InvoiceSearchFilter filter = const InvoiceSearchFilter(),
  int topK = 20,
  int exactFallbackMaxCandidates = 256,
  double? maximumDistance,
}) {
  return InvoiceVectorQuery(
    vector: vector,
    modelId: _modelId,
    dimensions: _dimensions,
    searchTextSchemaVersion: _searchSchema,
    embeddingSchemaVersion: _embeddingSchema,
    filter: filter,
    topK: topK,
    oversampleFactor: 5,
    exactFallbackMaxCandidates: exactFallbackMaxCandidates,
    maximumDistance: maximumDistance,
  );
}

Future<int> _save(
  ObjectBoxDatabase database, {
  required String merchant,
  required String keywordText,
  int? totalMinor,
  String? currencyCode,
  DateTime? purchaseDate,
  DateTime? warrantyEndDate,
  String? documentType,
  List<double>? vector,
  InvoiceEmbeddingStatus embeddingStatus = InvoiceEmbeddingStatus.pending,
  String embeddingModelId = _modelId,
}) {
  final now = DateTime.utc(2026, 8, 9);
  return database.invoices.save(
    InvoiceWrite(
      invoice: InvoiceEntity(
        merchant: merchant,
        merchantNormalized: merchant.toLowerCase(),
        documentType: documentType,
        documentTypeNormalized: DocumentTypeNormalization.normalize(
          documentType,
        ),
        purchaseDate: purchaseDate,
        totalMinor: totalMinor,
        currencyCode: currencyCode,
        warrantyEndDate: warrantyEndDate,
        searchableText: 'المتجر: $merchant',
        keywordText: keywordText,
        imagePath: '$merchant.jpg',
        sourceType: 'gallery',
        embedding: vector,
        embeddingModelId: vector == null ? null : embeddingModelId,
        embeddingDimensions: vector == null ? null : _dimensions,
        embeddingStatus: embeddingStatus.name,
        embeddingSchemaVersion: vector == null ? 0 : _embeddingSchema,
        searchTextSchemaVersion: _searchSchema,
        createdAt: now,
        updatedAt: now,
        reviewedAt: now,
      ),
      items: [
        InvoiceItemEntity(
          invoiceId: 0,
          name: merchant.startsWith('متجر A5') ? 'Samsung A5' : merchant,
          nameNormalized: merchant.toLowerCase(),
        ),
      ],
    ),
  );
}

List<double> _basis(int index) {
  final vector = List<double>.filled(_dimensions, 0);
  vector[index] = 1;
  return vector;
}

List<double> _normalized(List<double> prefix) {
  final norm = math.sqrt(
    prefix.fold<double>(0, (sum, value) => sum + value * value),
  );
  return [
    ...prefix.map((value) => value / norm),
    ...List<double>.filled(_dimensions - prefix.length, 0),
  ];
}
