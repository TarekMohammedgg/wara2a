import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../invoice_details/models/invoice.dart';
import '../models/search_filters.dart';
import '../models/search_intent.dart';
import '../models/search_result.dart';
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
  final SemanticSearchGate semanticGate;
  final bool usedKeywordFallback;
  final String? errorMessage;

  bool get hasQuery => query.trim().isNotEmpty;

  @override
  List<Object?> get props => [
    status,
    query,
    intent,
    filters,
    results,
    pendingEmbeddingCount,
    semanticGate,
    usedKeywordFallback,
    errorMessage,
  ];
}

class SearchCubit extends Cubit<SearchState> {
  SearchCubit(this._repository) : super(const SearchState());

  final SearchRepository _repository;
  int _requestGeneration = 0;

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
    emit(const SearchState());
  }

  Future<void> _execute(SearchIntent intent, SearchFilters filters) async {
    final generation = ++_requestGeneration;
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
    try {
      final response = await _repository.search(
        intent.toRequest(editedFilters: filters),
      );
      if (generation != _requestGeneration || isClosed) return;
      emit(
        SearchState(
          status: response.results.isEmpty
              ? SearchStatus.empty
              : SearchStatus.success,
          query: intent.rawQuery,
          intent: intent,
          filters: filters,
          results: response.results,
          pendingEmbeddingCount: response.pendingEmbeddingCount,
          semanticGate: response.semanticGate,
          usedKeywordFallback: response.usedKeywordFallback,
        ),
      );
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

  @override
  Future<void> close() async {
    _requestGeneration++;
    if (_repository case SearchResourceLifecycle lifecycle) {
      await lifecycle.releaseSearchResources();
    }
    return super.close();
  }
}
