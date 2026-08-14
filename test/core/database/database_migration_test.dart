import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wara2a/core/ai/embedding/open_router_embedding_artifact.dart';
import 'package:wara2a/core/database/database_migration_runner.dart';
import 'package:wara2a/core/database/database_versions.dart';
import 'package:wara2a/core/database/entities/database_metadata_entity.dart';
import 'package:wara2a/core/database/entities/invoice_entity.dart';
import 'package:wara2a/core/database/entities/invoice_item_entity.dart';
import 'package:wara2a/core/database/invoice_embedding_status.dart';
import 'package:wara2a/core/database/objectbox_database.dart';
import 'package:wara2a/objectbox.g.dart';

void main() {
  test(
    'opens a real v2 768-dimensional store and preserves rows for reindex',
    () async {
      final source = Directory(
        'test/fixtures/database/legacy_embedding_768_v2',
      );
      final legacyData = File('${source.path}/data.mdb');
      expect(await legacyData.length(), 40960);
      expect(
        sha256.convert(await legacyData.readAsBytes()).toString(),
        '741f43019369c16796d75c4a106fb89bdf020ef2443872b2d8e26883b06eed31',
      );
      final directory = await Directory.systemTemp.createTemp(
        'wara2a_legacy_768_migrate_',
      );
      await _copyDirectory(source, directory);

      final database = await ObjectBoxDatabase.open(directory: directory.path);
      try {
        final invoices = database.store.box<InvoiceEntity>().getAll();
        expect(invoices, hasLength(1));
        final migrated = invoices.single;
        expect(migrated.merchant, 'Legacy merchant');
        expect(migrated.invoiceNumber, 'LEGACY-768');
        expect(migrated.imagePath, 'legacy/legacy.png');
        expect(migrated.legacyEmbedding768, isNull);
        expect(migrated.embedding, isNull);
        expect(migrated.embeddingModelId, isNull);
        expect(migrated.embeddingDimensions, isNull);
        expect(migrated.embeddingStatus, InvoiceEmbeddingStatus.pending.name);
        expect(
          migrated.embeddingSchemaVersion,
          DatabaseVersions.embeddingSchema,
        );
        expect(
          migrated.searchTextSchemaVersion,
          DatabaseVersions.searchTextSchema,
        );
        expect(migrated.searchableText, contains('legacy merchant'));
        expect(migrated.searchableText, contains('legacy item'));

        final items = database.store.box<InvoiceItemEntity>().getAll();
        expect(items, hasLength(1));
        expect(items.single.invoiceId, migrated.id);
        expect(items.single.name, 'Legacy item');
        expect(items.single.quantity, 2);

        final metadata = {
          for (final entry
              in database.store.box<DatabaseMetadataEntity>().getAll())
            entry.key: entry.value,
        };
        expect(
          metadata[DatabaseVersions.databaseSchemaKey],
          DatabaseVersions.databaseSchema.toString(),
        );
        expect(
          metadata[DatabaseVersions.searchTextSchemaKey],
          DatabaseVersions.searchTextSchema.toString(),
        );
        expect(
          metadata[DatabaseVersions.embeddingSchemaKey],
          DatabaseVersions.embeddingSchema.toString(),
        );

        final pending = await database.invoices.getPendingEmbeddings(
          modelId: OpenRouterEmbeddingArtifact.modelId,
          searchTextSchemaVersion: DatabaseVersions.searchTextSchema,
          embeddingSchemaVersion: DatabaseVersions.embeddingSchema,
        );
        expect(pending.map((record) => record.invoice.id), [migrated.id]);
      } finally {
        database.close();
        if (await directory.exists()) {
          await directory.delete(recursive: true);
        }
      }
    },
  );

  test('reopens previous app metadata and invalidates stale vectors', () async {
    final directory = await Directory.systemTemp.createTemp('wara2a_migrate_');
    var database = await ObjectBoxDatabase.open(directory: directory.path);
    final now = DateTime.utc(2026, 8, 9);
    final invoice = InvoiceEntity(
      searchableText: 'old representation',
      keywordText: 'old',
      imagePath: 'invoice.jpg',
      sourceType: 'gallery',
      embedding: List<double>.filled(OpenRouterEmbeddingArtifact.dimensions, 0)
        ..[0] = 1,
      embeddingModelId: 'old-model',
      embeddingDimensions: OpenRouterEmbeddingArtifact.dimensions,
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
        embedding: List<double>.filled(
          OpenRouterEmbeddingArtifact.dimensions,
          0,
        )..[0] = 1,
        embeddingModelId: OpenRouterEmbeddingArtifact.modelId,
        embeddingDimensions: OpenRouterEmbeddingArtifact.dimensions,
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

Future<void> _copyDirectory(Directory source, Directory target) async {
  if (!await source.exists()) {
    throw StateError('Missing legacy ObjectBox fixture at ${source.path}.');
  }
  await target.create(recursive: true);
  await for (final entity in source.list(followLinks: false)) {
    final destination =
        '${target.path}${Platform.pathSeparator}${entity.uri.pathSegments.last}';
    if (entity is File) {
      await entity.copy(destination);
    } else if (entity is Directory) {
      await _copyDirectory(entity, Directory(destination));
    }
  }
}
