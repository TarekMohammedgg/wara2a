import '../../objectbox.g.dart';
import '../ai/embedding/embedding_gemma_artifact.dart';
import '../ai/embedding/embedding_vector_validator.dart';
import '../utils/invoice_search_text_builder.dart';
import '../utils/document_type_normalization.dart';
import 'database_versions.dart';
import 'entities/database_metadata_entity.dart';
import 'entities/invoice_entity.dart';
import 'entities/invoice_item_entity.dart';
import 'invoice_embedding_status.dart';

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
      final embeddingVersion = _readVersion(
        metadata,
        DatabaseVersions.embeddingSchemaKey,
      );
      if (searchTextVersion > DatabaseVersions.searchTextSchema) {
        throw UnsupportedDatabaseVersion(
          searchTextVersion,
          DatabaseVersions.searchTextSchema,
        );
      }
      if (embeddingVersion > DatabaseVersions.embeddingSchema) {
        throw UnsupportedDatabaseVersion(
          embeddingVersion,
          DatabaseVersions.embeddingSchema,
        );
      }

      for (final invoice in invoices.getAll()) {
        final normalizedDocumentType = DocumentTypeNormalization.normalize(
          invoice.documentType,
        );
        final documentTypeStale =
            invoice.documentTypeNormalized != normalizedDocumentType;
        if (documentTypeStale) {
          invoice.documentTypeNormalized = normalizedDocumentType;
        }
        final searchTextStale =
            searchTextVersion < DatabaseVersions.searchTextSchema ||
            invoice.searchTextSchemaVersion !=
                DatabaseVersions.searchTextSchema;
        if (searchTextStale) {
          final items = _itemsFor(invoice.id);
          final rebuilt = InvoiceSearchTextBuilder.build(
            merchant: invoice.merchant,
            documentType: invoice.documentType,
            invoiceNumber: invoice.invoiceNumber,
            purchaseDate: invoice.purchaseDate,
            totalMinor: invoice.totalMinor,
            currencyCode: invoice.currencyCode,
            warrantyMonths: invoice.warrantyMonths,
            warrantyEndDate: invoice.warrantyEndDate,
            items: items.map(
              (item) => InvoiceSearchItemInput(
                name: item.name,
                quantity: item.quantity,
              ),
            ),
          );
          invoice
            ..searchableText = rebuilt.searchableText
            ..keywordText = rebuilt.keywordText
            ..searchTextSchemaVersion = DatabaseVersions.searchTextSchema;
        }
        final embeddingStale =
            searchTextStale ||
            embeddingVersion < DatabaseVersions.embeddingSchema ||
            invoice.embeddingSchemaVersion !=
                DatabaseVersions.embeddingSchema ||
            invoice.embeddingModelId != EmbeddingGemmaArtifact.modelId ||
            invoice.embeddingDimensions != EmbeddingGemmaArtifact.dimensions ||
            invoice.embeddingStatus != InvoiceEmbeddingStatus.ready.name ||
            !_isValidVector(invoice.embedding);
        if (embeddingStale) {
          invoice
            ..embedding = null
            ..embeddingModelId = null
            ..embeddingDimensions = null
            ..embeddingStatus = InvoiceEmbeddingStatus.pending.name
            ..embeddingSchemaVersion = DatabaseVersions.embeddingSchema
            ..embeddingUpdatedAt = null
            ..embeddingFailureCode = null
            ..embeddingAttemptId = null;
        }
        if (searchTextStale || embeddingStale || documentTypeStale) {
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

  List<InvoiceItemEntity> _itemsFor(int invoiceId) {
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

  bool _isValidVector(List<double>? vector) {
    if (vector == null) return false;
    try {
      EmbeddingVectorValidator.validateNormalized(
        vector,
        dimensions: EmbeddingGemmaArtifact.dimensions,
      );
      return true;
    } on InvalidEmbeddingVector {
      return false;
    }
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
