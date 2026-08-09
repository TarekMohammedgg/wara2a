import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:wara2a/core/database/objectbox_database.dart';
import 'package:wara2a/core/storage/invoice_file_cleaner.dart';
import 'package:wara2a/features/invoice_details/models/invoice.dart';
import 'package:wara2a/features/invoice_details/repositories/objectbox_invoice_repository.dart';

void main() {
  late Directory directory;
  late ObjectBoxDatabase database;
  late ObjectBoxInvoiceRepository repository;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('wara2a_repo_');
    database = await ObjectBoxDatabase.open(
      directory: '${directory.path}/database',
    );
    repository = ObjectBoxInvoiceRepository(
      store: database.invoices,
      fileCleaner: LocalInvoiceFileCleaner(managedRoot: directory.path),
    );
  });

  tearDown(() async {
    database.close();
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  test('searchable edits clear a previously stored embedding', () async {
    final id = await repository.save(_invoice());
    final saved = (await repository.get(id))!;

    await repository.save(
      saved.copyWith(
        searchableText: '${saved.searchableText}\nupdated',
        updatedAt: DateTime.utc(2026, 8, 10),
      ),
    );

    final updated = (await repository.get(id))!;
    expect(updated.createdAt, saved.createdAt);
    expect(updated.embedding, isNull);
    expect(updated.embeddingModelId, isNull);
    expect(updated.embeddingDimensions, isNull);
  });

  test('delete cleans managed image and thumbnail files', () async {
    final image = File('${directory.path}/invoice.jpg');
    final thumbnail = File('${directory.path}/invoice-thumb.jpg');
    await image.writeAsString('image');
    await thumbnail.writeAsString('thumbnail');
    final id = await repository.save(
      _invoice(imagePath: image.path, thumbnailPath: thumbnail.path),
    );

    expect(await repository.delete(id), isTrue);
    expect(await image.exists(), isFalse);
    expect(await thumbnail.exists(), isFalse);
    expect(await repository.get(id), isNull);
  });
}

Invoice _invoice({String? imagePath, String? thumbnailPath}) {
  final now = DateTime.utc(2026, 8, 9);
  return Invoice(
    merchant: 'بي تك',
    documentType: 'فاتورة شراء',
    purchaseDate: now,
    totalMinor: 2499900,
    currencyCode: 'EGP',
    searchableText: 'المتجر: بي تك',
    keywordText: 'بي تك',
    imagePath: imagePath ?? 'invoice.jpg',
    thumbnailPath: thumbnailPath,
    sourceType: InvoiceSourceType.camera,
    embedding: List<double>.filled(768, 0)..[0] = 1,
    embeddingModelId: 'test-embedding',
    embeddingDimensions: 768,
    searchTextSchemaVersion: 1,
    createdAt: now,
    updatedAt: now,
    reviewedAt: now,
    items: const [InvoiceItem(name: 'Samsung Galaxy A56', quantity: 1)],
  );
}
