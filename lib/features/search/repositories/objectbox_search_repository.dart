import '../../../core/ai/embedding/embedding_engine.dart';
import '../../../core/database/database_versions.dart';
import '../../../core/database/invoice_record.dart';
import '../../../core/database/invoice_search_spec.dart';
import '../../../core/database/invoice_store.dart';
import '../../../core/utils/arabic_query_normalization/arabic_query_normalizer.dart';
import '../../invoice_details/models/invoice.dart';
import '../../invoice_details/repositories/invoice_entity_mapper.dart';
import '../models/search_filters.dart';
import '../models/search_intent.dart';
import '../models/search_intent_router.dart';
import '../models/search_request.dart';
import '../models/search_result.dart';
import '../models/search_route_type.dart';
import 'invoice_embedding_indexer.dart';
import 'search_repository.dart';

class ObjectBoxSearchRepository
    implements SearchRepository, SearchResourceLifecycle {
  const ObjectBoxSearchRepository({
    required this.store,
    required this.engine,
    required this.indexer,
    required this.intentRouter,
    this.calibration = const SemanticSearchCalibration.blocked(),
  });

  final InvoiceStore store;
  final EmbeddingEngine engine;
  final InvoiceEmbeddingIndexer indexer;
  final SearchIntentRouter intentRouter;
  final SemanticSearchCalibration calibration;

  @override
  SearchIntent interpret(String rawQuery) => intentRouter.parse(rawQuery);

  @override
  Future<int> pendingEmbeddingCount() => indexer.pendingCount();

  @override
  Future<PendingEmbeddingSyncResult> reindexPendingEmbeddings() async {
    final pendingBefore = await pendingEmbeddingCount();
    if (pendingBefore == 0) {
      return const PendingEmbeddingSyncResult(
        remaining: 0,
        indexed: 0,
        unavailable: 0,
        failed: 0,
      );
    }
    late final EmbeddingEngineSnapshot snapshot;
    try {
      snapshot = await engine.refresh();
    } on Object catch (error) {
      return PendingEmbeddingSyncResult(
        remaining: pendingBefore,
        indexed: 0,
        unavailable: pendingBefore,
        failed: 0,
        modelReady: false,
        modelMessage: error.toString(),
      );
    }
    if (!snapshot.canEmbed) {
      return PendingEmbeddingSyncResult(
        remaining: pendingBefore,
        indexed: 0,
        unavailable: pendingBefore,
        failed: 0,
        modelReady: false,
        modelMessage:
            snapshot.message ??
            'OpenRouter embedding is not ready. Add an API key in Settings.',
      );
    }
    // Keep the embedding client warm for the next search; unload happens when the
    // search session releases resources or the app backgrounds.
    final report = await indexer.reindexPending();
    final remaining = await pendingEmbeddingCount();
    return PendingEmbeddingSyncResult(
      remaining: remaining,
      indexed: report.indexed,
      unavailable: report.unavailable,
      failed: report.failed,
      modelReady: true,
      modelMessage: snapshot.message,
    );
  }

  @override
  Future<void> cancelSearchOperation() async {
    await indexer.cancelReindex();
    await engine.cancel();
  }

  @override
  Future<void> releaseSearchResources() async {
    await cancelSearchOperation();
    await engine.unload();
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
      semanticGate: SemanticSearchGate.none,
      usedKeywordFallback: fast.usedKeywordFallback && semantic.results.isEmpty,
      results: mergeSearchResults(fast.results, semantic.results),
    );
  }

  @override
  Future<SearchResponse> searchFast(SearchRequest request) async {
    final pending = await pendingEmbeddingCount();
    return switch (request.route) {
      SearchRouteType.keyword => _keyword(request, pending),
      SearchRouteType.structured => _structured(request, pending),
      SearchRouteType.semantic ||
      SearchRouteType.hybrid => _softKeywordResponse(request, pending),
    };
  }

  @override
  Future<SearchResponse> searchSemantic(SearchRequest request) async {
    final pending = await pendingEmbeddingCount();
    if (!request.route.requiresEmbedding) {
      return _empty(request, pending);
    }
    return _semanticVectorsOnly(request, pending);
  }

  Future<SearchResponse> _keyword(SearchRequest request, int pending) async {
    final tokens = _tokens(request.contentQuery);
    if (tokens.isEmpty) return _empty(request, pending);
    final hits = await store.searchExactKeywords(
      InvoiceKeywordQuery(normalizedTokens: tokens, limit: 50),
    );
    return SearchResponse(
      request: request,
      pendingEmbeddingCount: pending,
      results: hits.map(
        (hit) => SearchResult<Invoice>(
          invoiceId: hit.record.invoice.id,
          value: InvoiceEntityMapper.fromRecord(hit.record),
          route: request.route,
          matchKind: SearchMatchKind.exact,
          matchedKeywords: tokens,
        ),
      ),
    );
  }

  Future<SearchResponse> _structured(SearchRequest request, int pending) async {
    final filter = _databaseFilter(request.filters);
    final tokens = _tokens(request.contentQuery);
    final hits = tokens.isEmpty
        ? await store.searchFiltered(filter, limit: 50)
        : await store.searchExactKeywords(
            InvoiceKeywordQuery(
              normalizedTokens: tokens,
              filter: filter,
              limit: 50,
            ),
          );
    return SearchResponse(
      request: request,
      pendingEmbeddingCount: pending,
      results: hits.map(
        (hit) => SearchResult<Invoice>(
          invoiceId: hit.record.invoice.id,
          value: InvoiceEntityMapper.fromRecord(hit.record),
          route: request.route,
          matchKind: SearchMatchKind.filtered,
          matchedKeywords: tokens,
        ),
      ),
    );
  }

  /// Pure ANN path. Returns empty results when the model/index cannot help so
  /// the cubit can keep a prior keyword paint.
  Future<SearchResponse> _semanticVectorsOnly(
    SearchRequest request,
    int pending,
  ) async {
    if (!calibration.canReturnSemanticResults) {
      return _empty(request, pending);
    }
    late final EmbeddingEngineSnapshot availability;
    try {
      availability = await engine.refresh();
    } on Object {
      return _empty(request, pending);
    }
    if (!availability.canEmbed || availability.modelId != calibration.modelId) {
      return _empty(request, pending);
    }

    final query = request.contentQuery.trim().isEmpty
        ? request.normalizedQuery
        : request.contentQuery;
    late final EmbeddingOutput output;
    try {
      output = await engine.embedQuery(query);
    } on Object {
      return _empty(request, pending);
    }
    if (!calibration.accepts(output)) {
      return _empty(request, pending);
    }

    final hits = await store.searchNearest(
      InvoiceVectorQuery(
        vector: output.vector,
        modelId: output.modelId,
        dimensions: output.dimensions,
        searchTextSchemaVersion: DatabaseVersions.searchTextSchema,
        embeddingSchemaVersion: output.schemaVersion,
        filter: request.route == SearchRouteType.hybrid
            ? _databaseFilter(request.filters)
            : const InvoiceSearchFilter(),
        topK: 20,
        oversampleFactor: 5,
        maximumDistance: calibration.maximumCosineDistance,
      ),
    );
    final tokens = _tokens(request.contentQuery);
    final ranked =
        hits
            .map((hit) {
              final matched = _matchedTokens(
                hit.record.invoice.keywordText,
                tokens,
              );
              final distance = hit.distance!;
              final boost = request.route == SearchRouteType.hybrid
                  ? (matched.length * 0.02).clamp(0.0, 0.06)
                  : 0.0;
              return (
                rankDistance: distance - boost,
                result: SearchResult<Invoice>(
                  invoiceId: hit.record.invoice.id,
                  value: InvoiceEntityMapper.fromRecord(hit.record),
                  route: request.route,
                  matchKind: request.route == SearchRouteType.hybrid
                      ? SearchMatchKind.hybrid
                      : SearchMatchKind.semantic,
                  distance: distance,
                  matchedKeywords: matched,
                ),
              );
            })
            .toList(growable: false)
          ..sort((left, right) {
            final byRank = left.rankDistance.compareTo(right.rankDistance);
            if (byRank != 0) return byRank;
            return left.result.invoiceId.compareTo(right.result.invoiceId);
          });
    return SearchResponse(
      request: request,
      pendingEmbeddingCount: pending,
      results: ranked.map((entry) => entry.result),
    );
  }

  Future<SearchResponse> _softKeywordResponse(
    SearchRequest request,
    int pending,
  ) async {
    final filter = request.route == SearchRouteType.hybrid
        ? _databaseFilter(request.filters)
        : const InvoiceSearchFilter();
    final ranked = await _softKeywordHits(
      contentQuery: request.contentQuery,
      filter: filter,
    );
    return SearchResponse(
      request: request,
      pendingEmbeddingCount: pending,
      semanticGate: SemanticSearchGate.none,
      usedKeywordFallback: ranked.isNotEmpty,
      results: ranked.map(
        (entry) => SearchResult<Invoice>(
          invoiceId: entry.record.invoice.id,
          value: InvoiceEntityMapper.fromRecord(entry.record),
          route: request.route,
          matchKind: SearchMatchKind.exact,
          matchedKeywords: entry.matchedTokens,
        ),
      ),
    );
  }

  Future<List<({InvoiceRecord record, List<String> matchedTokens})>>
  _softKeywordHits({
    required String contentQuery,
    required InvoiceSearchFilter filter,
  }) async {
    final tokens = _significantTokens(contentQuery);
    if (tokens.isEmpty) return const [];

    final matchedById = <int, ({InvoiceRecord record, Set<String> tokens})>{};
    for (final token in tokens) {
      final hits = await store.searchExactKeywords(
        InvoiceKeywordQuery(
          normalizedTokens: [token],
          filter: filter,
          limit: 50,
        ),
      );
      for (final hit in hits) {
        final id = hit.record.invoice.id;
        final existing = matchedById[id];
        if (existing == null) {
          matchedById[id] = (record: hit.record, tokens: {token});
        } else {
          existing.tokens.add(token);
        }
      }
    }

    final ranked = matchedById.values.toList(growable: false)
      ..sort((left, right) {
        final byCount = right.tokens.length.compareTo(left.tokens.length);
        if (byCount != 0) return byCount;
        return right.record.invoice.id.compareTo(left.record.invoice.id);
      });
    return ranked
        .map(
          (entry) => (
            record: entry.record,
            matchedTokens: entry.tokens.toList(growable: false),
          ),
        )
        .toList(growable: false);
  }

  SearchResponse _empty(SearchRequest request, int pending) => SearchResponse(
    request: request,
    results: const [],
    pendingEmbeddingCount: pending,
  );
}

List<String> _tokens(String value) => ArabicQueryNormalizer.normalizeForKeyword(
  value,
).split(' ').where((token) => token.isNotEmpty).toSet().toList(growable: false);

/// Content tokens useful for recall on natural-language Arabic/English queries.
List<String> _significantTokens(String value) {
  final tokens = <String>{};
  for (final raw in _tokens(value)) {
    for (final token in _keywordVariants(raw)) {
      if (token.length < 2) continue;
      if (_searchStopwords.contains(token)) continue;
      tokens.add(token);
    }
  }
  final identifiers = tokens
      .where(
        (token) =>
            RegExp(r'[a-z]').hasMatch(token) &&
            RegExp(r'[0-9]').hasMatch(token),
      )
      .toList(growable: false);
  if (identifiers.isNotEmpty) return identifiers;
  return tokens.toList(growable: false);
}

List<String> _keywordVariants(String token) {
  final variants = <String>{token};
  if (token.startsWith('ال') && token.length > 3) {
    variants.add(token.substring(2));
  }
  return variants.toList(growable: false);
}

const Set<String> _searchStopwords = {
  'فاتورة',
  'الفاتورة',
  'فواتير',
  'الفواتير',
  'بتاعة',
  'بتاع',
  'بتاعت',
  'اللي',
  'الي',
  'الذي',
  'التي',
  'اشترى',
  'اشتري',
  'اشتريت',
  'اشتريته',
  'اشتريتها',
  'اشتريتو',
  'من',
  'في',
  'على',
  'الى',
  'إلي',
  'عن',
  'مع',
  'هذا',
  'هذه',
  'ده',
  'دي',
  'كان',
  'كانت',
  'عايز',
  'عاوز',
  'أريد',
  'اريد',
  'the',
  'a',
  'an',
  'of',
  'from',
  'for',
  'with',
  'invoice',
  'receipt',
  'bought',
  'buy',
  'purchase',
};

List<String> _matchedTokens(String keywordText, List<String> tokens) => tokens
    .where((token) => keywordText.contains(' $token '))
    .toList(growable: false);

InvoiceSearchFilter _databaseFilter(SearchFilters filters) {
  final amount = filters.amount;
  final purchaseDate = filters.purchaseDate;
  final warrantyEndDate = filters.warrantyEndDate;
  return InvoiceSearchFilter(
    amount: amount == null
        ? null
        : InvoiceAmountFilter(
            minimumMinor: amount.minimumMinor,
            minimumInclusive: amount.minimumInclusive,
            maximumMinor: amount.maximumMinor,
            maximumInclusive: amount.maximumInclusive,
          ),
    purchaseDate: purchaseDate == null
        ? null
        : InvoiceDateFilter(
            startInclusive: purchaseDate.startInclusive,
            endExclusive: purchaseDate.endExclusive,
          ),
    warrantyEndDate: warrantyEndDate == null
        ? null
        : InvoiceDateFilter(
            startInclusive: warrantyEndDate.startInclusive,
            endExclusive: warrantyEndDate.endExclusive,
          ),
    currencyCode: filters.currencyCode,
  );
}
