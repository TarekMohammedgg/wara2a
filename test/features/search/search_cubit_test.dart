import 'package:flutter_test/flutter_test.dart';
import 'package:wara2a/features/invoice_details/models/invoice.dart';
import 'package:wara2a/features/search/models/search_filters.dart';
import 'package:wara2a/features/search/models/search_intent.dart';
import 'package:wara2a/features/search/models/search_intent_router.dart';
import 'package:wara2a/features/search/models/search_request.dart';
import 'package:wara2a/features/search/models/search_result.dart';
import 'package:wara2a/features/search/repositories/search_repository.dart';
import 'package:wara2a/features/search/view_models/search_cubit.dart';

void main() {
  test('submits a keyword query and exposes real invoice results', () async {
    final repository = _FakeSearchRepository(
      responder: (request) => SearchResponse(
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
    expect(repository.requests.single.contentQuery, 'samsung a56');
  });

  test(
    'keeps semantic search visibly gated instead of returning fake hits',
    () async {
      final repository = _FakeSearchRepository(
        responder: (request) => SearchResponse(
          request: request,
          results: const [],
          pendingEmbeddingCount: 1,
          semanticGate: SemanticSearchGate.calibrationRequired,
        ),
      );
      final cubit = SearchCubit(repository);
      addTearDown(cubit.close);

      await cubit.submit('الفاتورة بتاعة الموبايل اللي اشتريته من فترة');

      expect(cubit.state.status, SearchStatus.empty);
      expect(cubit.state.semanticGate, SemanticSearchGate.calibrationRequired);
      expect(cubit.state.results, isEmpty);
    },
  );

  test('removing an inferred filter reruns with editable filters', () async {
    final repository = _FakeSearchRepository(
      responder: (request) => SearchResponse(
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
    expect(repository.requests, hasLength(2));
    expect(repository.requests.last.filters.amount, isNull);
  });
}

class _FakeSearchRepository implements SearchRepository {
  _FakeSearchRepository({required this.responder});

  final SearchResponse Function(SearchRequest request) responder;
  final List<SearchRequest> requests = [];
  final SearchIntentRouter router = SearchIntentRouter(
    clock: () => DateTime.utc(2026, 8, 9),
  );

  @override
  SearchIntent interpret(String rawQuery) => router.parse(rawQuery);

  @override
  Future<int> pendingEmbeddingCount() async => 0;

  @override
  Future<SearchResponse> search(SearchRequest request) async {
    requests.add(request);
    return responder(request);
  }
}

Invoice _invoice() {
  final now = DateTime.utc(2026, 8, 9);
  return Invoice(
    id: 7,
    merchant: 'بي تك',
    documentType: 'فاتورة شراء',
    purchaseDate: now,
    totalMinor: 2499900,
    currencyCode: 'EGP',
    searchableText: 'المتجر: بي تك\nالمنتجات: samsung a56',
    keywordText: ' بي تك samsung a56 ',
    imagePath: 'invoice.jpg',
    sourceType: InvoiceSourceType.camera,
    searchTextSchemaVersion: 2,
    createdAt: now,
    updatedAt: now,
    reviewedAt: now,
    items: const [InvoiceItem(name: 'Samsung A56')],
  );
}
