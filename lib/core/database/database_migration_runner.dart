import '../../objectbox.g.dart';
import 'database_versions.dart';
import 'entities/database_metadata_entity.dart';
import 'entities/invoice_entity.dart';

class UnsupportedDatabaseVersion implements Exception {
  const UnsupportedDatabaseVersion(this.stored, this.supported);

  final int stored;
  final int supported;

  @override
  String toString() =>
      'Database version $stored is newer than supported version $supported.';
}

class DatabaseMigrationRunner {
  const DatabaseMigrationRunner(this.store);

  final Store store;

  void migrate() {
    store.runInTransaction(TxMode.write, () {
      final metadata = store.box<DatabaseMetadataEntity>();
      final invoices = store.box<InvoiceEntity>();

      final databaseVersion = _readVersion(
        metadata,
        DatabaseVersions.databaseSchemaKey,
      );
      if (databaseVersion > DatabaseVersions.databaseSchema) {
        throw UnsupportedDatabaseVersion(
          databaseVersion,
          DatabaseVersions.databaseSchema,
        );
      }

      final searchTextVersion = _readVersion(
        metadata,
        DatabaseVersions.searchTextSchemaKey,
      );
      if (searchTextVersion < DatabaseVersions.searchTextSchema) {
        for (final invoice in invoices.getAll()) {
          invoice
            ..searchTextSchemaVersion = DatabaseVersions.searchTextSchema
            ..embedding = null
            ..embeddingModelId = null
            ..embeddingDimensions = null;
          invoices.put(invoice);
        }
      }

      _writeVersion(
        metadata,
        DatabaseVersions.databaseSchemaKey,
        DatabaseVersions.databaseSchema,
      );
      _writeVersion(
        metadata,
        DatabaseVersions.searchTextSchemaKey,
        DatabaseVersions.searchTextSchema,
      );
      _writeVersion(
        metadata,
        DatabaseVersions.embeddingSchemaKey,
        DatabaseVersions.embeddingSchema,
      );
    });
  }

  int _readVersion(Box<DatabaseMetadataEntity> box, String key) {
    final query = box.query(DatabaseMetadataEntity_.key.equals(key)).build();
    try {
      return int.tryParse(query.findFirst()?.value ?? '') ?? 0;
    } finally {
      query.close();
    }
  }

  void _writeVersion(Box<DatabaseMetadataEntity> box, String key, int version) {
    final query = box.query(DatabaseMetadataEntity_.key.equals(key)).build();
    try {
      final existing = query.findFirst();
      box.put(
        DatabaseMetadataEntity(
          id: existing?.id ?? 0,
          key: key,
          value: version.toString(),
          updatedAt: DateTime.now().toUtc(),
        ),
      );
    } finally {
      query.close();
    }
  }
}
