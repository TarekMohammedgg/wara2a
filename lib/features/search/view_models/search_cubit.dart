import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../invoice_details/models/invoice.dart';
import '../models/search_filters.dart';
import '../models/search_intent.dart';
import '../models/search_result.dart';
import '../models/search_route_type.dart';
import '../repositories/search_repository.dart';

enum SearchStatus { initial, loading, success, empty, failure }

class SearchState extends Equatable {
  const SearchState({
    this.status = SearchStatus.initial,
    this.query = '',
    this.intent,
    this.filters = const SearchFilters(),
    this.results = const [],
    this.pendingEmbeddingCount = 0,
    this.indexingPending = false,
    this.indexFeedback,
    this.semanticGate = SemanticSearchGate.none,
    this.usedKeywordFallback = false,
    this.errorMessage,
  });

  final SearchStatus status;
  final String query;
  final SearchIntent? intent;
  final SearchFilters filters;
  final List<SearchResult<Invoice>> results;
  final int pendingEmbeddingCount;
  final bool indexingPending;
  final String? indexFeedback;
  final SemanticSearchGate semanticGate;
  final bool usedKeywordFallback;
  final String? errorMessage;

  bool get hasQuery => query.trim().isNotEmpty;

  SearchState copyWith({
    SearchStatus? status,
    String? query,
    SearchIntent? intent,
    SearchFilters? filters,
    List<SearchResult<Invoice>>? results,
    int? pendingEmbeddingCount,
    bool? indexingPending,
    Object? indexFeedback = _unset,
    SemanticSearchGate? semanticGate,
    bool? usedKeywordFallback,
    String? errorMessage,
  }) {
    return SearchState(
      status: status ?? this.status,
      query: query ?? this.query,
      intent: intent ?? this.intent,
      filters: filters ?? this.filters,
      results: results ?? this.results,
      pendingEmbeddingCount:
          pendingEmbeddingCount ?? this.pendingEmbeddingCount,
      indexingPending: indexingPending ?? this.indexingPending,
      indexFeedback: identical(indexFeedback, _unset)
          ? this.indexFeedback
          : indexFeedback as String?,
      semanticGate: semanticGate ?? this.semanticGate,
      usedKeywordFallback: usedKeywordFallback ?? this.usedKeywordFallback,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  static const Object _unset = Object();

  @override
  List<Object?> get props => [
    status,
    query,
    intent,
    filters,
    results,
    pendingEmbeddingCount,
    indexingPending,
    indexFeedback,
    semanticGate,
    usedKeywordFallback,
    errorMessage,
  ];
}

class SearchCubit extends Cubit<SearchState> {
  SearchCubit(this._repository) : super(const SearchState());

  final SearchRepository _repository;
  int _requestGeneration = 0;
  bool _reindexInFlight = false;

  Future<void> submit(String rawQuery) async {
    final query = rawQuery.trim();
    if (query.isEmpty) {
      clear();
      return;
    }
    try {
      final intent = _repository.interpret(query);
      await _execute(intent, intent.filters);
    } on Object catch (error) {
      emit(
        SearchState(
          status: SearchStatus.failure,
          query: query,
          errorMessage: error.toString(),
        ),
      );
    }
  }

  Future<void> applyFilters(SearchFilters filters) async {
    final intent = state.intent;
    if (intent == null) return;
    await _execute(intent, filters);
  }

  Future<void> removeFilter(SearchFilterField field) =>
      applyFilters(state.filters.clear(field));

  void clear() {
    _requestGeneration++;
    unawaited(_cancelInFlightSearch());
    emit(const SearchState());
  }

  void clearIndexFeedback() {
    if (state.indexFeedback != null) {
      emit(state.copyWith(indexFeedback: null));
    }
  }

  /// Background catch-up for pending vectors. Quiet: no search-screen banners.
  Future<PendingEmbeddingSyncResult?> syncPendingEmbeddings({
    bool force = false,
  }) async {
    if (_reindexInFlight) return null;
    _reindexInFlight = true;
    try {
      final result = await _repository.reindexPendingEmbeddings();
      if (isClosed) return result;
      emit(state.copyWith(pendingEmbeddingCount: result.remaining));
      final intent = state.intent;
      if (result.remaining == 0 &&
          result.indexed > 0 &&
          intent != null &&
          state.hasQuery) {
        await _execute(intent, state.filters, syncEmbeddings: false);
      }
      return result;
    } on Object {
      return null;
    } finally {
      _reindexInFlight = false;
    }
  }

  Future<void> _execute(
    SearchIntent intent,
    SearchFilters filters, {
    bool syncEmbeddings = true,
  }) async {
    final generation = ++_requestGeneration;
    await _cancelInFlightSearch();
    emit(
      SearchState(
        status: SearchStatus.loading,
        query: intent.rawQuery,
        intent: intent,
        filters: filters,
        results: state.results,
        pendingEmbeddingCount: state.pendingEmbeddingCount,
      ),
    );

    final request = intent.toRequest(editedFilters: filters);
    try {
      // Phase A: instant keyword/structured/soft-keyword paint.
      final fast = await _repository.searchFast(request);
      if (generation != _requestGeneration || isClosed) return;
      emit(
        SearchState(
          status: fast.results.isEmpty
              ? (intent.route.requiresEmbedding
                    ? SearchStatus.loading
                    : SearchStatus.empty)
              : SearchStatus.success,
          query: intent.rawQuery,
          intent: intent,
          filters: filters,
          results: fast.results,
          pendingEmbeddingCount: fast.pendingEmbeddingCount,
          usedKeywordFallback: fast.usedKeywordFallback,
        ),
      );

      // Phase B: silent semantic enrich when the router asks for meaning search.
      if (intent.route.requiresEmbedding) {
        final semantic = await _repository.searchSemantic(request);
        if (generation != _requestGeneration || isClosed) return;
        final merged = semantic.results.isEmpty
            ? fast.results
            : mergeSearchResults(fast.results, semantic.results);
        emit(
          SearchState(
            status: merged.isEmpty ? SearchStatus.empty : SearchStatus.success,
            query: intent.rawQuery,
            intent: intent,
            filters: filters,
            results: merged,
            pendingEmbeddingCount: semantic.pendingEmbeddingCount,
            usedKeywordFallback:
                fast.usedKeywordFallback && semantic.results.isEmpty,
          ),
        );
      }

      final pending = state.pendingEmbeddingCount;
      if (syncEmbeddings && pending > 0) {
        unawaited(syncPendingEmbeddings(force: true));
      }
    } on Object catch (error) {
      if (generation != _requestGeneration || isClosed) return;
      emit(
        SearchState(
          status: SearchStatus.failure,
          query: intent.rawQuery,
          intent: intent,
          filters: filters,
          errorMessage: error.toString(),
        ),
      );
    }
  }

  Future<void> _cancelInFlightSearch() async {
    if (_repository case SearchResourceLifecycle lifecycle) {
      try {
        await lifecycle.cancelSearchOperation();
      } on Object {
        // Best-effort cancel; the next request still proceeds.
      }
    }
  }

  @override
  Future<void> close() async {
    _requestGeneration++;
    if (_repository case SearchResourceLifecycle lifecycle) {
      await lifecycle.releaseSearchResources();
    }
    return super.close();
  }
}
