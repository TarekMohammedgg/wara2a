import '../../../core/ai/embedding/embedding_engine.dart';
import '../../../core/database/database_versions.dart';
import '../../../core/database/invoice_search_spec.dart';
import '../../../core/database/invoice_store.dart';
import '../../../core/utils/arabic_query_normalization/arabic_query_normalizer.dart';
import '../../../core/utils/document_type_normalization.dart';
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
  Future<void> releaseSearchResources() async {
    await engine.cancel();
    await engine.unload();
  }

  @override
  Future<SearchResponse> search(SearchRequest request) async {
    final pending = await pendingEmbeddingCount();
    return switch (request.route) {
      SearchRouteType.keyword => _keyword(request, pending),
      SearchRouteType.structured => _structured(request, pending),
      SearchRouteType.semantic ||
      SearchRouteType.hybrid => _semantic(request, pending),
    };
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

  Future<SearchResponse> _semantic(SearchRequest request, int pending) async {
    if (!calibration.canReturnSemanticResults) {
      return _semanticFallback(
        request,
        pending,
        SemanticSearchGate.calibrationRequired,
      );
    }
    late final EmbeddingEngineSnapshot availability;
    try {
      availability = await engine.refresh();
    } on Object {
      return _semanticFallback(
        request,
        pending,
        SemanticSearchGate.runtimeFailure,
      );
    }
    if (!availability.canEmbed) {
      return _semanticFallback(
        request,
        pending,
        SemanticSearchGate.modelUnavailable,
      );
    }
    if (availability.modelId != calibration.modelId) {
      return _semanticFallback(
        request,
        pending,
        SemanticSearchGate.calibrationRequired,
      );
    }

    final query = request.contentQuery.trim().isEmpty
        ? request.normalizedQuery
        : request.contentQuery;
    late final EmbeddingOutput output;
    try {
      output = await engine.embedQuery(query);
    } on EmbeddingInputTooLongException {
      return _semanticFallback(
        request,
        pending,
        SemanticSearchGate.queryTooLong,
      );
    } on EmbeddingUnavailableException {
      return _semanticFallback(
        request,
        pending,
        SemanticSearchGate.modelUnavailable,
      );
    } on Object {
      return _semanticFallback(
        request,
        pending,
        SemanticSearchGate.runtimeFailure,
      );
    }
    if (!calibration.accepts(output)) {
      return _semanticFallback(
        request,
        pending,
        SemanticSearchGate.calibrationRequired,
      );
    }

    // Keep persistence failures visible to the Cubit instead of presenting a
    // damaged index or database as a model-capability problem.
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

  Future<SearchResponse> _semanticFallback(
    SearchRequest request,
    int pending,
    SemanticSearchGate gate,
  ) async {
    if (request.route != SearchRouteType.hybrid) {
      return SearchResponse(
        request: request,
        results: const [],
        pendingEmbeddingCount: pending,
        semanticGate: gate,
      );
    }
    final tokens = _fallbackTokens(request.contentQuery);
    if (tokens.isEmpty) {
      return SearchResponse(
        request: request,
        results: const [],
        pendingEmbeddingCount: pending,
        semanticGate: gate,
      );
    }
    final hits = await store.searchExactKeywords(
      InvoiceKeywordQuery(
        normalizedTokens: tokens,
        filter: _databaseFilter(request.filters),
        limit: 50,
      ),
    );
    return SearchResponse(
      request: request,
      pendingEmbeddingCount: pending,
      semanticGate: gate,
      usedKeywordFallback: true,
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

  SearchResponse _empty(SearchRequest request, int pending) => SearchResponse(
    request: request,
    results: const [],
    pendingEmbeddingCount: pending,
  );
}

List<String> _tokens(String value) => ArabicQueryNormalizer.normalizeForKeyword(
  value,
).split(' ').where((token) => token.isNotEmpty).toSet().toList(growable: false);

List<String> _fallbackTokens(String value) {
  final tokens = _tokens(value);
  final identifiers = tokens
      .where(
        (token) =>
            RegExp(r'[a-z]').hasMatch(token) &&
            RegExp(r'[0-9]').hasMatch(token),
      )
      .toList(growable: false);
  if (identifiers.isNotEmpty) return identifiers;
  // A semantic failure must not silently turn descriptive words into exact
  // claims. Only explicit quotes or mixed letter/digit identifiers receive
  // the limited exact-keyword fallback.
  return RegExp(r'"[^"]+"').hasMatch(value) ? tokens : const <String>[];
}

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
    documentType: switch (filters.documentType) {
      SearchDocumentType.purchaseInvoice =>
        DocumentTypeNormalization.purchaseInvoice,
      SearchDocumentType.receipt => DocumentTypeNormalization.receipt,
      SearchDocumentType.creditNote => DocumentTypeNormalization.creditNote,
      SearchDocumentType.warrantyCertificate =>
        DocumentTypeNormalization.warrantyCertificate,
      null => null,
    },
  );
}
