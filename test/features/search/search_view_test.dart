import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wara2a/features/invoice_details/models/invoice.dart';
import 'package:wara2a/features/search/models/search_intent.dart';
import 'package:wara2a/features/search/models/search_intent_router.dart';
import 'package:wara2a/features/search/models/search_request.dart';
import 'package:wara2a/features/search/models/search_result.dart';
import 'package:wara2a/features/search/repositories/search_repository.dart';
import 'package:wara2a/features/search/view_models/search_cubit.dart';
import 'package:wara2a/features/search/views/search_view.dart';
import 'package:wara2a/l10n/app_localizations.dart';

void main() {
  testWidgets('renders repository results instead of mock invoices', (
    tester,
  ) async {
    final repository = _ViewSearchRepository();
    await tester.pumpWidget(_TestSearchApp(repository: repository));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Samsung A56');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(find.text('B.TECH reviewed'), findsOneWidget);
    expect(find.text('1 matching results'), findsOneWidget);
    expect(find.text('Exact match'), findsNothing);
    expect(find.text('Semantic match'), findsNothing);
    expect(repository.requests, hasLength(1));
  });
}

class _TestSearchApp extends StatelessWidget {
  const _TestSearchApp({required this.repository});

  final SearchRepository repository;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      locale: const Locale('en'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [AppLocalizations.delegate],
      home: Scaffold(
        body: BlocProvider(
          create: (_) => SearchCubit(repository),
          child: const SearchView(),
        ),
      ),
    );
  }
}

class _ViewSearchRepository implements SearchRepository {
  final router = SearchIntentRouter(clock: () => DateTime.utc(2026, 8, 9));
  final List<SearchRequest> requests = [];

  @override
  SearchIntent interpret(String rawQuery) => router.parse(rawQuery);

  @override
  Future<int> pendingEmbeddingCount() async => 0;

  @override
  Future<PendingEmbeddingSyncResult> reindexPendingEmbeddings() async =>
      const PendingEmbeddingSyncResult(
        remaining: 0,
        indexed: 0,
        unavailable: 0,
        failed: 0,
      );

  @override
  Future<SearchResponse> searchFast(SearchRequest request) async {
    requests.add(request);
    return SearchResponse(
      request: request,
      pendingEmbeddingCount: 0,
      results: [
        SearchResult<Invoice>(
          invoiceId: 42,
          value: _invoice(),
          route: request.route,
          matchKind: SearchMatchKind.exact,
          matchedKeywords: const ['samsung', 'a56'],
        ),
      ],
    );
  }

  @override
  Future<SearchResponse> searchSemantic(SearchRequest request) async {
    return SearchResponse(
      request: request,
      pendingEmbeddingCount: 0,
      results: const [],
    );
  }

  @override
  Future<SearchResponse> search(SearchRequest request) => searchFast(request);
}

Invoice _invoice() {
  final now = DateTime.utc(2026, 8, 9);
  return Invoice(
    id: 42,
    merchant: 'B.TECH reviewed',
    purchaseDate: now,
    totalMinor: 2499900,
    currencyCode: 'EGP',
    searchableText: 'merchant: b.tech reviewed',
    keywordText: ' b tech reviewed samsung a56 ',
    imagePath: 'invoice.jpg',
    sourceType: InvoiceSourceType.camera,
    searchTextSchemaVersion: 2,
    createdAt: now,
    updatedAt: now,
    reviewedAt: now,
    items: const [InvoiceItem(name: 'Samsung A56')],
  );
}
