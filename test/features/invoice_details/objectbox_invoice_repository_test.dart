import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:wara2a/core/database/objectbox_database.dart';
import 'package:wara2a/core/database/database_versions.dart';
import 'package:wara2a/core/database/invoice_embedding_status.dart';
import 'package:wara2a/core/database/invoice_record.dart';
import 'package:wara2a/core/ai/embedding/open_router_embedding_artifact.dart';
import 'package:wara2a/core/storage/invoice_file_cleaner.dart';
import 'package:wara2a/features/invoice_details/models/invoice.dart';
import 'package:wara2a/features/invoice_details/repositories/objectbox_invoice_repository.dart';

void main() {
  late Directory directory;
  late ObjectBoxDatabase database;
  late ObjectBoxInvoiceRepository repository;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('wara2a_repo_');
    database = await ObjectBoxDatabase.open(
      directory: '${directory.path}/database',
    );
    repository = ObjectBoxInvoiceRepository(
      store: database.invoices,
      fileCleaner: LocalInvoiceFileCleaner(managedRoot: directory.path),
    );
  });

  tearDown(() async {
    database.close();
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  test('searchable edits clear a previously stored embedding', () async {
    final id = await repository.save(_invoice());
    final pending = (await repository.get(id))!;
    await _markReady(database, pending);
    final saved = (await repository.get(id))!;
    expect(saved.embeddingStatus, InvoiceEmbeddingStatus.ready);

    await repository.save(
      saved.copyWith(
        merchant: 'B.Tech Online',
        // Repository boundaries must ignore caller-supplied stale derivatives.
        searchableText: saved.searchableText,
        keywordText: saved.keywordText,
        updatedAt: DateTime.utc(2026, 8, 10),
      ),
    );

    final updated = (await repository.get(id))!;
    expect(updated.createdAt, saved.createdAt);
    expect(updated.embedding, isNull);
    expect(updated.embeddingModelId, isNull);
    expect(updated.embeddingDimensions, isNull);
    expect(updated.embeddingStatus, InvoiceEmbeddingStatus.pending);
    expect(updated.searchableText, contains('b.tech online'));
    expect(updated.keywordText, contains('online'));
  });

  test('non-searchable edits preserve a current stored embedding', () async {
    final id = await repository.save(_invoice());
    final pending = (await repository.get(id))!;
    await _markReady(database, pending);
    final ready = (await repository.get(id))!;

    await repository.save(
      ready.copyWith(
        rawExtractedText: 'updated audit text only',
        updatedAt: DateTime.utc(2026, 8, 10),
      ),
    );

    final updated = (await repository.get(id))!;
    expect(updated.embeddingStatus, InvoiceEmbeddingStatus.ready);
    expect(updated.embeddingModelId, OpenRouterEmbeddingArtifact.modelId);
    expect(
      updated.embedding,
      hasLength(OpenRouterEmbeddingArtifact.dimensions),
    );
  });

  test(
    'item edits rebuild derivatives even when the caller leaves them stale',
    () async {
      final id = await repository.save(_invoice());
      final pending = (await repository.get(id))!;
      await _markReady(database, pending);
      final ready = (await repository.get(id))!;

      await repository.save(
        ready.copyWith(
          searchableText: ready.searchableText,
          keywordText: ready.keywordText,
          items: const [InvoiceItem(name: 'Google Pixel 10', quantity: 2)],
          updatedAt: DateTime.utc(2026, 8, 10),
        ),
      );

      final updated = (await repository.get(id))!;
      expect(updated.embeddingStatus, InvoiceEmbeddingStatus.pending);
      expect(updated.embedding, isNull);
      expect(updated.searchableText, contains('google pixel 10 × 2'));
      expect(updated.keywordText, contains(' pixel '));
      expect(updated.keywordText, isNot(contains(' samsung ')));
    },
  );

  test('delete cleans managed image and thumbnail files', () async {
    final image = File('${directory.path}/invoice.jpg');
    final thumbnail = File('${directory.path}/invoice-thumb.jpg');
    await image.writeAsString('image');
    await thumbnail.writeAsString('thumbnail');
    final id = await repository.save(
      _invoice(imagePath: image.path, thumbnailPath: thumbnail.path),
    );

    expect(await repository.delete(id), isTrue);
    expect(await image.exists(), isFalse);
    expect(await thumbnail.exists(), isFalse);
    expect(await repository.get(id), isNull);
  });
}

Future<void> _markReady(ObjectBoxDatabase database, Invoice invoice) async {
  const attemptId = 'repository-test-attempt';
  final began = await database.invoices.updateEmbeddingStatus(
    InvoiceEmbeddingStatusUpdate(
      invoiceId: invoice.id,
      status: InvoiceEmbeddingStatus.indexing,
      expectedSearchableText: invoice.searchableText,
      expectedSearchTextSchemaVersion: invoice.searchTextSchemaVersion,
      attemptId: attemptId,
    ),
  );
  expect(began, isTrue);
  final committed = await database.invoices.commitEmbedding(
    InvoiceEmbeddingCommit(
      invoiceId: invoice.id,
      expectedSearchableText: invoice.searchableText,
      expectedSearchTextSchemaVersion: invoice.searchTextSchemaVersion,
      expectedAttemptId: attemptId,
      vector: List<double>.filled(OpenRouterEmbeddingArtifact.dimensions, 0)
        ..[0] = 1,
      modelId: OpenRouterEmbeddingArtifact.modelId,
      dimensions: OpenRouterEmbeddingArtifact.dimensions,
      embeddingSchemaVersion: DatabaseVersions.embeddingSchema,
      indexedAt: DateTime.utc(2026, 8, 9, 1),
    ),
  );
  expect(committed, isTrue);
}

Invoice _invoice({String? imagePath, String? thumbnailPath}) {
  final now = DateTime.utc(2026, 8, 9);
  return Invoice(
    merchant: 'بي تك',
    purchaseDate: now,
    totalMinor: 2499900,
    currencyCode: 'EGP',
    searchableText: 'المتجر: بي تك',
    keywordText: 'بي تك',
    imagePath: imagePath ?? 'invoice.jpg',
    thumbnailPath: thumbnailPath,
    sourceType: InvoiceSourceType.camera,
    embedding: List<double>.filled(OpenRouterEmbeddingArtifact.dimensions, 0)
      ..[0] = 1,
    embeddingModelId: OpenRouterEmbeddingArtifact.modelId,
    embeddingDimensions: OpenRouterEmbeddingArtifact.dimensions,
    searchTextSchemaVersion: 1,
    createdAt: now,
    updatedAt: now,
    reviewedAt: now,
    items: const [InvoiceItem(name: 'Samsung Galaxy A56', quantity: 1)],
  );
}
