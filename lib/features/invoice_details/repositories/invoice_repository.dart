import '../models/invoice.dart';

abstract interface class InvoiceRepository {
  Future<int> save(Invoice invoice);
  Future<Invoice?> get(int id);
  Future<List<Invoice>> getAll();
  Stream<List<Invoice>> watchAll();
  Future<bool> delete(int id);
}
