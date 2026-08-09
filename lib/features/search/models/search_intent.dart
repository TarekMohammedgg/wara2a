import 'package:equatable/equatable.dart';

import 'search_filters.dart';
import 'search_request.dart';
import 'search_route_type.dart';

enum SearchParseIssue {
  ambiguousAmount,
  conflictingAmountBounds,
  ambiguousCurrency,
  ambiguousDate,
  ambiguousWarrantyDate,
  ambiguousDocumentType,
  lowConfidenceFilter,
}

class SearchFilterInference extends Equatable {
  const SearchFilterInference({
    required this.field,
    required this.confidence,
    required this.evidence,
  });

  final SearchFilterField field;
  final double confidence;
  final String evidence;

  @override
  List<Object?> get props => [field, confidence, evidence];
}

class SearchIntent extends Equatable {
  SearchIntent({
    required this.rawQuery,
    required this.normalizedQuery,
    required this.contentQuery,
    required this.route,
    required this.filters,
    required this.confidence,
    Iterable<SearchFilterInference> inferences = const [],
    Iterable<SearchParseIssue> issues = const [],
  }) : inferences = List.unmodifiable(inferences),
       issues = List.unmodifiable(issues);

  final String rawQuery;
  final String normalizedQuery;
  final String contentQuery;
  final SearchRouteType route;
  final SearchFilters filters;
  final double confidence;
  final List<SearchFilterInference> inferences;
  final List<SearchParseIssue> issues;

  SearchRequest toRequest({SearchFilters? editedFilters}) {
    final requestedFilters = editedFilters ?? filters;
    var requestedRoute = route;
    if (editedFilters != null) {
      final semanticContent =
          route == SearchRouteType.semantic || route == SearchRouteType.hybrid;
      requestedRoute = requestedFilters.isEmpty
          ? (semanticContent
                ? SearchRouteType.semantic
                : SearchRouteType.keyword)
          : (semanticContent
                ? SearchRouteType.hybrid
                : SearchRouteType.structured);
    }
    return SearchRequest(
      rawQuery: rawQuery,
      normalizedQuery: normalizedQuery,
      contentQuery: contentQuery,
      route: requestedRoute,
      filters: requestedFilters,
    );
  }

  @override
  List<Object?> get props => [
    rawQuery,
    normalizedQuery,
    contentQuery,
    route,
    filters,
    confidence,
    inferences,
    issues,
  ];
}
