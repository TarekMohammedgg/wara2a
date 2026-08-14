import 'package:equatable/equatable.dart';

import 'search_route_type.dart';

enum SearchMatchKind { exact, filtered, semantic, hybrid }

class SearchResult<T> extends Equatable {
  SearchResult({
    required this.invoiceId,
    required this.value,
    required this.route,
    required this.matchKind,
    this.distance,
    Iterable<String> matchedKeywords = const [],
  }) : matchedKeywords = List.unmodifiable(matchedKeywords);

  final int invoiceId;
  final T value;
  final SearchRouteType route;
  final SearchMatchKind matchKind;
  final double? distance;
  final List<String> matchedKeywords;

  @override
  List<Object?> get props => [
    invoiceId,
    value,
    route,
    matchKind,
    distance,
    matchedKeywords,
  ];
}

/// Merges a fast keyword paint with a later semantic enrich by invoice id.
List<SearchResult<T>> mergeSearchResults<T>(
  List<SearchResult<T>> fast,
  List<SearchResult<T>> semantic,
) {
  final byId = <int, SearchResult<T>>{
    for (final result in fast) result.invoiceId: result,
  };
  for (final result in semantic) {
    final existing = byId[result.invoiceId];
    if (existing == null) {
      byId[result.invoiceId] = result;
      continue;
    }
    final existingDistance = existing.distance;
    final nextDistance = result.distance;
    if (nextDistance != null &&
        (existingDistance == null || nextDistance < existingDistance)) {
      byId[result.invoiceId] = result;
    }
  }
  final merged = byId.values.toList(growable: false)
    ..sort((left, right) {
      final leftDistance = left.distance;
      final rightDistance = right.distance;
      if (leftDistance != null && rightDistance != null) {
        final byDistance = leftDistance.compareTo(rightDistance);
        if (byDistance != 0) return byDistance;
      } else if (leftDistance != null) {
        return -1;
      } else if (rightDistance != null) {
        return 1;
      }
      return right.invoiceId.compareTo(left.invoiceId);
    });
  return merged;
}
