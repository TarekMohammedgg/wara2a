import '../../../core/database/database_versions.dart';
import '../../../core/database/invoice_embedding_status.dart';
import '../../../core/database/invoice_store.dart';
import '../../../core/storage/invoice_file_cleaner.dart';
import '../../../core/utils/invoice_search_text_builder.dart';
import '../models/invoice.dart';
import 'invoice_entity_mapper.dart';
import 'invoice_repository.dart';

class ObjectBoxInvoiceRepository implements InvoiceRepository {
  const ObjectBoxInvoiceRepository({
    required this.store,
    required this.fileCleaner,
  });

  final InvoiceStore store;
  final InvoiceFileCleaner fileCleaner;

  @override
  Future<int> save(Invoice invoice) async {
    final existing = invoice.id == 0 ? null : await get(invoice.id);
    if (invoice.id != 0 && existing == null) {
      throw InvoiceNotFoundException(invoice.id);
    }

    final searchText = InvoiceSearchTextBuilder.build(
      merchant: invoice.merchant,
      documentType: invoice.documentType,
      invoiceNumber: invoice.invoiceNumber,
      purchaseDate: invoice.purchaseDate,
      totalMinor: invoice.totalMinor,
      currencyCode: invoice.currencyCode,
      warrantyMonths: invoice.warrantyMonths,
      warrantyEndDate: invoice.warrantyEndDate,
      items: invoice.items.map(
        (item) =>
            InvoiceSearchItemInput(name: item.name, quantity: item.quantity),
      ),
    );
    final canonicalInvoice = invoice.copyWith(
      searchableText: searchText.searchableText,
      keywordText: searchText.keywordText,
      searchTextSchemaVersion: DatabaseVersions.searchTextSchema,
    );
    final searchChanged =
        existing != null &&
        (existing.searchableText != canonicalInvoice.searchableText ||
            existing.keywordText != canonicalInvoice.keywordText ||
            existing.searchTextSchemaVersion !=
                canonicalInvoice.searchTextSchemaVersion);
    final prepared = existing != null && !searchChanged
        ? canonicalInvoice.copyWith(
            createdAt: existing.createdAt,
            embedding: existing.embedding,
            embeddingModelId: existing.embeddingModelId,
            embeddingDimensions: existing.embeddingDimensions,
            embeddingStatus: existing.embeddingStatus,
            embeddingSchemaVersion: existing.embeddingSchemaVersion,
            embeddingUpdatedAt: existing.embeddingUpdatedAt,
            embeddingFailureCode: existing.embeddingFailureCode,
            embeddingAttemptId: existing.embeddingAttemptId,
            searchTextSchemaVersion: DatabaseVersions.searchTextSchema,
          )
        : canonicalInvoice.copyWith(
            createdAt: existing?.createdAt ?? canonicalInvoice.createdAt,
            searchTextSchemaVersion: DatabaseVersions.searchTextSchema,
            embeddingStatus: InvoiceEmbeddingStatus.pending,
            embeddingSchemaVersion: DatabaseVersions.embeddingSchema,
            clearEmbedding: true,
          );
    return store.save(InvoiceEntityMapper.toWrite(prepared));
  }

  @override
  Future<Invoice?> get(int id) async {
    final record = await store.get(id);
    return record == null ? null : InvoiceEntityMapper.fromRecord(record);
  }

  @override
  Future<List<Invoice>> getAll() async {
    final records = await store.getAll();
    return records.map(InvoiceEntityMapper.fromRecord).toList(growable: false);
  }

  @override
  Stream<List<Invoice>> watchAll() => store.watchRecent().map(
    (records) =>
        records.map(InvoiceEntityMapper.fromRecord).toList(growable: false),
  );

  @override
  Future<bool> delete(int id) async {
    final files = await store.delete(id);
    if (files == null) return false;
    await fileCleaner.deleteOwnedFiles([files.imagePath, files.thumbnailPath]);
    return true;
  }
}
