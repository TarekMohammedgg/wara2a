import 'package:path_provider/path_provider.dart';

import '../../objectbox.g.dart';
import 'database_migration_runner.dart';
import 'invoice_store.dart';

class ObjectBoxDatabase {
  ObjectBoxDatabase._(this.store) : invoices = InvoiceStore(store);

  final Store store;
  final InvoiceStore invoices;

  static Future<ObjectBoxDatabase> open({String? directory}) async {
    final resolvedDirectory = directory == null
        ? '${(await getApplicationDocumentsDirectory()).path}/wara2a-objectbox'
        : directory;
    final store = await openStore(directory: resolvedDirectory);
    try {
      final database = ObjectBoxDatabase._(store);
      DatabaseMigrationRunner(store).migrate();
      return database;
    } catch (_) {
      if (!store.isClosed()) store.close();
      rethrow;
    }
  }

  void close() {
    if (!store.isClosed()) store.close();
  }
}
