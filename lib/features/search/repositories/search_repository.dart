import 'package:equatable/equatable.dart';

import '../../invoice_details/models/invoice.dart';
import '../models/search_filters.dart';
import '../models/search_intent.dart';
import '../models/search_request.dart';
import '../models/search_result.dart';

enum SemanticSearchGate {
  none,
  calibrationRequired,
  modelUnavailable,
  queryTooLong,
  runtimeFailure,
}

class SemanticSearchCalibration extends Equatable {
  const SemanticSearchCalibration.blocked()
    : approved = false,
      maximumCosineDistance = null,
      corpusVersion = null,
      labeledQueryCount = 0;

  const SemanticSearchCalibration.approved({
    required double maximumCosineDistance,
    required String approvedCorpusVersion,
    required int labeledQueryCount,
  }) : assert(maximumCosineDistance >= 0 && maximumCosineDistance <= 2),
       assert(labeledQueryCount >= 100),
       approved = true,
       maximumCosineDistance = maximumCosineDistance,
       corpusVersion = approvedCorpusVersion,
       labeledQueryCount = labeledQueryCount;

  final bool approved;
  final double? maximumCosineDistance;
  final String? corpusVersion;
  final int labeledQueryCount;

  bool get canReturnSemanticResults =>
      approved &&
      maximumCosineDistance != null &&
      corpusVersion?.trim().isNotEmpty == true &&
      labeledQueryCount >= 100;

  @override
  List<Object?> get props => [
    approved,
    maximumCosineDistance,
    corpusVersion,
    labeledQueryCount,
  ];
}

class SearchResponse extends Equatable {
  SearchResponse({
    required this.request,
    required Iterable<SearchResult<Invoice>> results,
    required this.pendingEmbeddingCount,
    this.semanticGate = SemanticSearchGate.none,
    this.usedKeywordFallback = false,
  }) : results = List.unmodifiable(results);

  final SearchRequest request;
  final List<SearchResult<Invoice>> results;
  final int pendingEmbeddingCount;
  final SemanticSearchGate semanticGate;
  final bool usedKeywordFallback;

  @override
  List<Object?> get props => [
    request,
    results,
    pendingEmbeddingCount,
    semanticGate,
    usedKeywordFallback,
  ];
}

abstract interface class SearchRepository {
  SearchIntent interpret(String rawQuery);

  Future<SearchResponse> search(SearchRequest request);

  Future<int> pendingEmbeddingCount();
}

abstract interface class SearchResourceLifecycle {
  Future<void> releaseSearchResources();
}

extension SearchFiltersEditing on SearchFilters {
  bool get hasSemanticConstraint => isNotEmpty;
}
