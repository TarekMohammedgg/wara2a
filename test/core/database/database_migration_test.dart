import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:wara2a/core/database/database_versions.dart';
import 'package:wara2a/core/database/entities/database_metadata_entity.dart';
import 'package:wara2a/core/database/entities/invoice_entity.dart';
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
}
