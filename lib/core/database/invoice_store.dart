import 'dart:async';

import '../../objectbox.g.dart';
import 'entities/invoice_entity.dart';
import 'entities/invoice_item_entity.dart';
import 'invoice_record.dart';

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
