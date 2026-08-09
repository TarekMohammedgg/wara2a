import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:wara2a/core/ai/embedding/embedding_gemma_artifact.dart';
import 'package:wara2a/core/database/database_versions.dart';
import 'package:wara2a/core/database/entities/database_metadata_entity.dart';
import 'package:wara2a/core/database/entities/invoice_entity.dart';
import 'package:wara2a/core/database/invoice_embedding_status.dart';
import 'package:wara2a/core/database/database_migration_runner.dart';
import 'package:wara2a/core/database/objectbox_database.dart';
import 'package:wara2a/objectbox.g.dart';

void main() {
  test('reopens previous app metadata and invalidates stale vectors', () async {
    final directory = await Directory.systemTemp.createTemp('wara2a_migrate_');
    var database = await ObjectBoxDatabase.open(directory: directory.path);
    final now = DateTime.utc(2026, 8, 9);
    final invoice = InvoiceEntity(
      searchableText: 'old representation',
      keywordText: 'old',
      imagePath: 'invoice.jpg',
      sourceType: 'gallery',
      embedding: List<double>.filled(768, 0)..[0] = 1,
      embeddingModelId: 'old-model',
      embeddingDimensions: 768,
      searchTextSchemaVersion: 0,
      createdAt: now,
      updatedAt: now,
      reviewedAt: now,
    );
    final invoiceId = database.store.box<InvoiceEntity>().put(invoice);
    final metadataBox = database.store.box<DatabaseMetadataEntity>();
    final query = metadataBox
        .query(
          DatabaseMetadataEntity_.key.equals(
            DatabaseVersions.searchTextSchemaKey,
          ),
        )
        .build();
    final metadata = query.findFirst()!;
    query.close();
    metadata
      ..value = '0'
      ..updatedAt = now;
    metadataBox.put(metadata);
    database.close();

    database = await ObjectBoxDatabase.open(directory: directory.path);
    final migrated = database.store.box<InvoiceEntity>().get(invoiceId)!;

    expect(migrated.searchTextSchemaVersion, DatabaseVersions.searchTextSchema);
    expect(migrated.embedding, isNull);
    expect(migrated.embeddingModelId, isNull);
    expect(migrated.embeddingDimensions, isNull);

    database.close();
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  test('repairs per-row future search and embedding versions', () async {
    final directory = await Directory.systemTemp.createTemp(
      'wara2a_future_row_',
    );
    var database = await ObjectBoxDatabase.open(directory: directory.path);
    final now = DateTime.utc(2026, 8, 9);
    final id = database.store.box<InvoiceEntity>().put(
      InvoiceEntity(
        merchant: 'Future row',
        searchableText: 'future representation',
        keywordText: ' future ',
        imagePath: 'future.jpg',
        sourceType: 'gallery',
        embedding: List<double>.filled(768, 0)..[0] = 1,
        embeddingModelId: EmbeddingGemmaArtifact.modelId,
        embeddingDimensions: 768,
        embeddingStatus: InvoiceEmbeddingStatus.ready.name,
        embeddingSchemaVersion: 999,
        embeddingAttemptId: 'future-attempt',
        searchTextSchemaVersion: 999,
        createdAt: now,
        updatedAt: now,
        reviewedAt: now,
      ),
    );
    database.close();

    database = await ObjectBoxDatabase.open(directory: directory.path);
    final repaired = database.store.box<InvoiceEntity>().get(id)!;
    expect(repaired.searchTextSchemaVersion, DatabaseVersions.searchTextSchema);
    expect(repaired.embeddingSchemaVersion, DatabaseVersions.embeddingSchema);
    expect(repaired.searchableText, contains('future row'));
    expect(repaired.embeddingStatus, InvoiceEmbeddingStatus.pending.name);
    expect(repaired.embedding, isNull);
    expect(repaired.embeddingAttemptId, isNull);

    database.close();
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  test('closes the store when a future database version is rejected', () async {
    final directory = await Directory.systemTemp.createTemp(
      'wara2a_future_database_',
    );
    final database = await ObjectBoxDatabase.open(directory: directory.path);
    final metadataBox = database.store.box<DatabaseMetadataEntity>();
    final query = metadataBox
        .query(
          DatabaseMetadataEntity_.key.equals(
            DatabaseVersions.databaseSchemaKey,
          ),
        )
        .build();
    final metadata = query.findFirst()!;
    query.close();
    metadata
      ..value = '999'
      ..updatedAt = DateTime.utc(2026, 8, 9);
    metadataBox.put(metadata);
    database.close();

    await expectLater(
      ObjectBoxDatabase.open(directory: directory.path),
      throwsA(isA<UnsupportedDatabaseVersion>()),
    );
    final reopened = await openStore(directory: directory.path);
    expect(reopened.isClosed(), isFalse);
    reopened.close();

    if (await directory.exists()) await directory.delete(recursive: true);
  });
}
