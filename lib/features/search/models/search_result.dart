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
