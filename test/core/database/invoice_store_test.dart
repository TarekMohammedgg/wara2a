import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:wara2a/core/database/entities/invoice_entity.dart';
import 'package:wara2a/core/database/entities/invoice_item_entity.dart';
import 'package:wara2a/core/database/invoice_record.dart';
import 'package:wara2a/core/database/objectbox_database.dart';

void main() {
  late Directory directory;
  late ObjectBoxDatabase database;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('wara2a_store_');
    database = await ObjectBoxDatabase.open(directory: directory.path);
  });

  tearDown(() async {
    database.close();
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  test('saves and reads an invoice with its items atomically', () async {
    final observed = database.invoices.watchRecent().firstWhere(
      (records) => records.isNotEmpty,
    );
    final id = await database.invoices.save(
      InvoiceWrite(
        invoice: _invoice(),
        items: [
          InvoiceItemEntity(
            invoiceId: 0,
            name: 'هاتف',
            nameNormalized: 'هاتف',
            quantity: 1,
            lineTotalMinor: 10000,
          ),
        ],
      ),
    );

    final record = await database.invoices.get(id);
    expect(record?.invoice.merchant, 'متجر محلي');
    expect(record?.items.single.name, 'هاتف');
    expect((await observed).single.invoice.id, id);
  });

  test('rolls back invoice creation when an item is invalid', () async {
    await expectLater(
      database.invoices.save(
        InvoiceWrite(
          invoice: _invoice(),
          items: [
            InvoiceItemEntity(invoiceId: 0, name: '   ', nameNormalized: ''),
          ],
        ),
      ),
      throwsA(isA<Exception>()),
    );

    expect(await database.invoices.getAll(), isEmpty);
  });

  test('update replaces owned items without leaving old rows', () async {
    final id = await database.invoices.save(
      InvoiceWrite(
        invoice: _invoice(),
        items: [
          InvoiceItemEntity(invoiceId: 0, name: 'قديم', nameNormalized: 'قديم'),
        ],
      ),
    );
    final existing = (await database.invoices.get(id))!.invoice;
    existing
      ..merchant = 'متجر محدث'
      ..updatedAt = DateTime.utc(2026, 8, 10);

    await database.invoices.save(
      InvoiceWrite(
        invoice: existing,
        items: [
          InvoiceItemEntity(
            invoiceId: id,
            name: 'جديد',
            nameNormalized: 'جديد',
          ),
        ],
      ),
    );

    final updated = await database.invoices.get(id);
    expect(updated?.invoice.merchant, 'متجر محدث');
    expect(updated?.items.map((item) => item.name), ['جديد']);
  });

  test('delete removes invoice and item records', () async {
    final id = await database.invoices.save(
      InvoiceWrite(
        invoice: _invoice(),
        items: [
          InvoiceItemEntity(invoiceId: 0, name: 'عنصر', nameNormalized: 'عنصر'),
        ],
      ),
    );

    final deleted = await database.invoices.delete(id);

    expect(deleted?.imagePath, endsWith('invoice.jpg'));
    expect(await database.invoices.get(id), isNull);
    expect(await database.invoices.getAll(), isEmpty);
  });
}

InvoiceEntity _invoice() {
  final now = DateTime.utc(2026, 8, 9);
  return InvoiceEntity(
    merchant: 'متجر محلي',
    merchantNormalized: 'متجر محلي',
    purchaseDate: now,
    totalMinor: 10000,
    currencyCode: 'EGP',
    searchableText: 'المتجر: متجر محلي',
    keywordText: 'متجر محلي',
    imagePath: '${Directory.systemTemp.path}/invoice.jpg',
    sourceType: 'camera',
    searchTextSchemaVersion: 1,
    createdAt: now,
    updatedAt: now,
    reviewedAt: now,
  );
}
