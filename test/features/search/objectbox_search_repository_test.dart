import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:wara2a/core/ai/embedding/embedding_engine.dart';
import 'package:wara2a/core/ai/embedding/multilingual_e5_artifact.dart';
import 'package:wara2a/core/database/objectbox_database.dart';
import 'package:wara2a/core/storage/invoice_file_cleaner.dart';
import 'package:wara2a/core/utils/invoice_search_text_builder.dart';
import 'package:wara2a/features/invoice_details/models/invoice.dart';
import 'package:wara2a/features/invoice_details/repositories/objectbox_invoice_repository.dart';
import 'package:wara2a/features/search/models/search_intent_router.dart';
import 'package:wara2a/features/search/models/search_route_type.dart';
import 'package:wara2a/features/search/repositories/invoice_embedding_indexer.dart';
import 'package:wara2a/features/search/repositories/objectbox_search_repository.dart';
import 'package:wara2a/features/search/repositories/search_repository.dart';

void main() {
  late Directory directory;
  late ObjectBoxDatabase database;
  late ObjectBoxSearchRepository search;
  late ObjectBoxInvoiceRepository invoices;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('wara2a_search_repo_');
    database = await ObjectBoxDatabase.open(directory: directory.path);
    invoices = ObjectBoxInvoiceRepository(
      store: database.invoices,
      fileCleaner: const NoOpInvoiceFileCleaner(),
    );
    final engine = UnavailableEmbeddingEngine(
      modelId: MultilingualE5Artifact.modelId,
      reason: 'test model is intentionally unavailable',
    );
    search = ObjectBoxSearchRepository(
      store: database.invoices,
      engine: engine,
      indexer: InvoiceEmbeddingIndexer(
        store: database.invoices,
        engine: engine,
      ),
      intentRouter: SearchIntentRouter(clock: () => DateTime.utc(2026, 8, 9)),
    );
    await invoices.save(_invoice());
  });

  tearDown(() async {
    database.close();
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  test(
    'executes exact product/model keyword search against reviewed data',
    () async {
      final intent = search.interpret('Samsung A56');
      final response = await search.search(intent.toRequest());

      expect(intent.route, SearchRouteType.keyword);
      expect(response.results.single.value.merchant, 'بي تك');
      expect(response.results.single.distance, isNull);
    },
  );

  test(
    'applies amount, currency, document, and warranty metadata filters',
    () async {
      final amountIntent = search.interpret('فاتورة شراء فوق ١٠٠٠٠ جنيه');
      final amountResponse = await search.search(amountIntent.toRequest());
      final warrantyIntent = search.interpret(
        'الفواتير اللي ضمانها هيخلص الشهر ده',
      );
      final warrantyResponse = await search.search(warrantyIntent.toRequest());

      expect(amountIntent.route, SearchRouteType.structured);
      expect(amountResponse.results, hasLength(1));
      expect(warrantyResponse.results, hasLength(1));
    },
  );

  test('gates descriptive semantic search with no fabricated result', () async {
    final intent = search.interpret(
      'الفاتورة بتاعة الموبايل اللي اشتريته من فترة',
    );
    final response = await search.search(intent.toRequest());

    expect(intent.route, SearchRouteType.semantic);
    expect(response.results, isEmpty);
    expect(response.semanticGate, SemanticSearchGate.calibrationRequired);
    expect(response.pendingEmbeddingCount, 1);
  });

  test(
    'hybrid gate permits only exact identifier plus filter fallback',
    () async {
      final intent = search.interpret(
        'الفاتورة بتاعة Samsung A56 اللي اشتريته فوق ١٠٠٠٠ جنيه',
      );
      final response = await search.search(intent.toRequest());

      expect(intent.route, SearchRouteType.hybrid);
      expect(response.results, hasLength(1));
      expect(response.usedKeywordFallback, isTrue);
      expect(response.semanticGate, SemanticSearchGate.calibrationRequired);
    },
  );

  test('hybrid gate does not present descriptive words as exact', () async {
    final intent = search.interpret(
      'الفاتورة بتاعة الموبايل اللي اشتريته فوق ١٠٠٠٠ جنيه',
    );
    final response = await search.search(intent.toRequest());

    expect(intent.route, SearchRouteType.hybrid);
    expect(response.results, isEmpty);
    expect(response.usedKeywordFallback, isFalse);
    expect(response.semanticGate, SemanticSearchGate.calibrationRequired);
  });
}

Invoice _invoice() {
  final reviewedAt = DateTime.utc(2026, 8, 9);
  final purchaseDate = DateTime.utc(2026, 7, 20);
  final warrantyEndDate = DateTime.utc(2026, 8, 20);
  final searchText = InvoiceSearchTextBuilder.build(
    merchant: 'بي تك',
    documentType: 'فاتورة شراء',
    invoiceNumber: 'BT-A56-1',
    purchaseDate: purchaseDate,
    totalMinor: 2499900,
    currencyCode: 'EGP',
    warrantyMonths: 1,
    warrantyEndDate: warrantyEndDate,
    items: const [
      InvoiceSearchItemInput(name: 'Samsung Galaxy A56', quantity: 1),
    ],
  );
  return Invoice(
    merchant: 'بي تك',
    documentType: 'فاتورة شراء',
    purchaseDate: purchaseDate,
    totalMinor: 2499900,
    currencyCode: 'EGP',
    warrantyMonths: 1,
    warrantyEndDate: warrantyEndDate,
    invoiceNumber: 'BT-A56-1',
    searchableText: searchText.searchableText,
    keywordText: searchText.keywordText,
    imagePath: 'invoice.jpg',
    sourceType: InvoiceSourceType.camera,
    searchTextSchemaVersion: 2,
    createdAt: reviewedAt,
    updatedAt: reviewedAt,
    reviewedAt: reviewedAt,
    items: const [InvoiceItem(name: 'Samsung Galaxy A56', quantity: 1)],
  );
}
