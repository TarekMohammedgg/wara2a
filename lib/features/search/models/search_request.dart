import 'package:equatable/equatable.dart';

import 'search_filters.dart';
import 'search_route_type.dart';

class SearchRequest extends Equatable {
  const SearchRequest({
    required this.rawQuery,
    required this.normalizedQuery,
    required this.contentQuery,
    required this.route,
    required this.filters,
  });

  final String rawQuery;
  final String normalizedQuery;
  final String contentQuery;
  final SearchRouteType route;
  final SearchFilters filters;

  SearchRequest copyWith({
    String? rawQuery,
    String? normalizedQuery,
    String? contentQuery,
    SearchRouteType? route,
    SearchFilters? filters,
  }) {
    return SearchRequest(
      rawQuery: rawQuery ?? this.rawQuery,
      normalizedQuery: normalizedQuery ?? this.normalizedQuery,
      contentQuery: contentQuery ?? this.contentQuery,
      route: route ?? this.route,
      filters: filters ?? this.filters,
    );
  }

  @override
  List<Object?> get props => [
    rawQuery,
    normalizedQuery,
    contentQuery,
    route,
    filters,
  ];
}
