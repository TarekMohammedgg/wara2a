import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:wara2a/features/invoice_details/models/invoice.dart';
import 'package:wara2a/features/search/models/search_filters.dart';
import 'package:wara2a/features/search/models/search_intent.dart';
import 'package:wara2a/features/search/models/search_intent_router.dart';
import 'package:wara2a/features/search/models/search_request.dart';
import 'package:wara2a/features/search/models/search_result.dart';
import 'package:wara2a/features/search/models/search_route_type.dart';
import 'package:wara2a/features/search/repositories/search_repository.dart';
import 'package:wara2a/features/search/view_models/search_cubit.dart';

void main() {
  test('submits a keyword query and exposes real invoice results', () async {
    final repository = _FakeSearchRepository(
      fastResponder: (request) => SearchResponse(
        request: request,
        pendingEmbeddingCount: 2,
        results: [
          SearchResult<Invoice>(
            invoiceId: 7,
            value: _invoice(),
            route: request.route,
            matchKind: SearchMatchKind.exact,
            matchedKeywords: const ['samsung', 'a56'],
          ),
        ],
      ),
    );
    final cubit = SearchCubit(repository);
    addTearDown(cubit.close);

    await cubit.submit('Samsung A56');

    expect(cubit.state.status, SearchStatus.success);
    expect(cubit.state.results.single.invoiceId, 7);
    expect(cubit.state.pendingEmbeddingCount, 2);
    expect(repository.fastRequests.single.contentQuery, 'samsung a56');
    expect(repository.semanticRequests, isEmpty);
  });

  test(
    'paints keyword results first then merges silent semantic enrich',
    () async {
      final semanticStarted = Completer<void>();
      final allowSemantic = Completer<void>();
      final repository = _FakeSearchRepository(
        fastResponder: (request) => SearchResponse(
          request: request,
          pendingEmbeddingCount: 0,
          usedKeywordFallback: true,
          results: [
            SearchResult<Invoice>(
              invoiceId: 1,
              value: _invoice(id: 1, merchant: 'Keyword hit'),
              route: request.route,
              matchKind: SearchMatchKind.exact,
              matchedKeywords: const ['سماعة'],
            ),
          ],
        ),
        semanticResponder: (request) async {
          semanticStarted.complete();
          await allowSemantic.future;
          return SearchResponse(
            request: request,
            pendingEmbeddingCount: 0,
            results: [
              SearchResult<Invoice>(
                invoiceId: 2,
                value: _invoice(id: 2, merchant: 'Semantic hit'),
                route: request.route,
                matchKind: SearchMatchKind.semantic,
                distance: 0.21,
              ),
            ],
          );
        },
      );
      final cubit = SearchCubit(repository);
      addTearDown(cubit.close);

      final submitFuture = cubit.submit(
        'فاتورة السماعة اللي اشتريتها من معرض النور',
      );
      await semanticStarted.future;
      expect(cubit.state.status, SearchStatus.success);
      expect(cubit.state.results.single.invoiceId, 1);

      allowSemantic.complete();
      await submitFuture;

      expect(cubit.state.status, SearchStatus.success);
      expect(cubit.state.results.map((result) => result.invoiceId), [2, 1]);
      expect(repository.fastRequests, hasLength(1));
      expect(repository.semanticRequests, hasLength(1));
    },
  );

  test('keeps keyword paint when semantic enrich returns empty', () async {
    final repository = _FakeSearchRepository(
      fastResponder: (request) => SearchResponse(
        request: request,
        pendingEmbeddingCount: 1,
        usedKeywordFallback: true,
        results: [
          SearchResult<Invoice>(
            invoiceId: 7,
            value: _invoice(),
            route: request.route,
            matchKind: SearchMatchKind.exact,
          ),
        ],
      ),
      semanticResponder: (request) async => SearchResponse(
        request: request,
        results: const [],
        pendingEmbeddingCount: 1,
      ),
    );
    final cubit = SearchCubit(repository);
    addTearDown(cubit.close);

    await cubit.submit('الفاتورة بتاعة الموبايل اللي اشتريته من فترة');

    expect(cubit.state.status, SearchStatus.success);
    expect(cubit.state.semanticGate, SemanticSearchGate.none);
    expect(cubit.state.results.single.invoiceId, 7);
  });

  test('removing an inferred filter reruns with editable filters', () async {
    final repository = _FakeSearchRepository(
      fastResponder: (request) => SearchResponse(
        request: request,
        results: const [],
        pendingEmbeddingCount: 0,
      ),
    );
    final cubit = SearchCubit(repository);
    addTearDown(cubit.close);

    await cubit.submit('الفواتير فوق ١٠٠٠٠ جنيه');
    expect(cubit.state.filters.amount, isNotNull);
    await cubit.removeFilter(SearchFilterField.amount);

    expect(cubit.state.filters.amount, isNull);
    expect(repository.fastRequests, hasLength(2));
    expect(repository.fastRequests.last.filters.amount, isNull);
  });
}

class _FakeSearchRepository implements SearchRepository {
  _FakeSearchRepository({required this.fastResponder, this.semanticResponder});

  final SearchResponse Function(SearchRequest request) fastResponder;
  final Future<SearchResponse> Function(SearchRequest request)?
  semanticResponder;
  final List<SearchRequest> fastRequests = [];
  final List<SearchRequest> semanticRequests = [];
  final SearchIntentRouter router = SearchIntentRouter(
    clock: () => DateTime.utc(2026, 8, 9),
  );

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
    fastRequests.add(request);
    return fastResponder(request);
  }

  @override
  Future<SearchResponse> searchSemantic(SearchRequest request) async {
    semanticRequests.add(request);
    final responder = semanticResponder;
    if (responder != null) return responder(request);
    return SearchResponse(
      request: request,
      results: const [],
      pendingEmbeddingCount: 0,
    );
  }

  @override
  Future<SearchResponse> search(SearchRequest request) async {
    final fast = await searchFast(request);
    if (!request.route.requiresEmbedding) return fast;
    final semantic = await searchSemantic(request);
    if (semantic.results.isEmpty) return fast;
    return SearchResponse(
      request: request,
      pendingEmbeddingCount: semantic.pendingEmbeddingCount,
      results: mergeSearchResults(fast.results, semantic.results),
    );
  }
}

Invoice _invoice({int id = 7, String merchant = 'بي تك'}) {
  final now = DateTime.utc(2026, 8, 9);
  return Invoice(
    id: id,
    merchant: merchant,
    purchaseDate: now,
    totalMinor: 2499900,
    currencyCode: 'EGP',
    searchableText: 'المتجر: $merchant\nالمنتجات: samsung a56',
    keywordText: ' $merchant samsung a56 ',
    imagePath: 'invoice.jpg',
    sourceType: InvoiceSourceType.camera,
    searchTextSchemaVersion: 2,
    createdAt: now,
    updatedAt: now,
    reviewedAt: now,
    items: const [InvoiceItem(name: 'Samsung A56')],
  );
}
