import '../../../core/database/database_versions.dart';
import '../../../core/database/invoice_store.dart';
import '../../../core/storage/invoice_file_cleaner.dart';
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

    final searchChanged =
        existing != null &&
        (existing.searchableText != invoice.searchableText ||
            existing.searchTextSchemaVersion !=
                invoice.searchTextSchemaVersion);
    final prepared = invoice.copyWith(
      createdAt: existing?.createdAt ?? invoice.createdAt,
      searchTextSchemaVersion: DatabaseVersions.searchTextSchema,
      clearEmbedding: searchChanged,
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
