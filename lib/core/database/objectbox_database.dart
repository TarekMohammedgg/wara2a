import 'package:path_provider/path_provider.dart';

import '../../objectbox.g.dart';
import 'database_migration_runner.dart';
import 'invoice_store.dart';

class ObjectBoxDatabase {
  ObjectBoxDatabase._(this.store) : invoices = InvoiceStore(store);

  final Store store;
  final InvoiceStore invoices;

  static Future<ObjectBoxDatabase> open({String? directory}) async {
    final resolvedDirectory =
        directory ??
        '${(await getApplicationDocumentsDirectory()).path}/wara2a-objectbox';
    final store = await openStore(directory: resolvedDirectory);
    final database = ObjectBoxDatabase._(store);
    DatabaseMigrationRunner(store).migrate();
    return database;
  }

  void close() {
    if (!store.isClosed()) store.close();
  }
}
