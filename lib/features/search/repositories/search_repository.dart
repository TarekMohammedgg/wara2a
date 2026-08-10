import 'package:equatable/equatable.dart';

import '../../../core/ai/embedding/embedding_engine.dart';
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
      labeledQueryCount = 0,
      noResultQueryCount = 0,
      languages = const <String>[],
      modelId = null,
      modelSha256 = null,
      dimensions = null,
      embeddingSchemaVersion = null,
      promptContract = null;

  const SemanticSearchCalibration.approved({
    required double maximumCosineDistance,
    required String approvedCorpusVersion,
    required int labeledQueryCount,
    required int noResultQueryCount,
    required List<String> languages,
    required String modelId,
    required String modelSha256,
    required int dimensions,
    required int embeddingSchemaVersion,
    required String promptContract,
  }) : assert(maximumCosineDistance >= 0 && maximumCosineDistance <= 2),
       assert(labeledQueryCount >= 100),
       assert(noResultQueryCount > 0),
       assert(dimensions > 0),
       assert(embeddingSchemaVersion > 0),
       approved = true,
       maximumCosineDistance = maximumCosineDistance,
       corpusVersion = approvedCorpusVersion,
       labeledQueryCount = labeledQueryCount,
       noResultQueryCount = noResultQueryCount,
       languages = languages,
       modelId = modelId,
       modelSha256 = modelSha256,
       dimensions = dimensions,
       embeddingSchemaVersion = embeddingSchemaVersion,
       promptContract = promptContract;

  final bool approved;
  final double? maximumCosineDistance;
  final String? corpusVersion;
  final int labeledQueryCount;
  final int noResultQueryCount;
  final List<String> languages;
  final String? modelId;
  final String? modelSha256;
  final int? dimensions;
  final int? embeddingSchemaVersion;
  final String? promptContract;

  bool get canReturnSemanticResults =>
      approved &&
      maximumCosineDistance != null &&
      corpusVersion?.trim().isNotEmpty == true &&
      labeledQueryCount >= 100 &&
      noResultQueryCount > 0 &&
      const <String>{
        'ar',
        'en',
        'mixed',
      }.difference(languages.toSet()).isEmpty &&
      modelId?.trim().isNotEmpty == true &&
      RegExp(r'^[a-f0-9]{64}$').hasMatch(modelSha256 ?? '') &&
      dimensions != null &&
      embeddingSchemaVersion != null &&
      promptContract?.trim().isNotEmpty == true;

  bool accepts(EmbeddingOutput output) =>
      canReturnSemanticResults &&
      output.modelId == modelId &&
      output.dimensions == dimensions &&
      output.schemaVersion == embeddingSchemaVersion;

  @override
  List<Object?> get props => [
    approved,
    maximumCosineDistance,
    corpusVersion,
    labeledQueryCount,
    noResultQueryCount,
    languages,
    modelId,
    modelSha256,
    dimensions,
    embeddingSchemaVersion,
    promptContract,
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
