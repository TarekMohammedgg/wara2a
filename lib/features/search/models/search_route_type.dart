enum SearchRouteType { keyword, structured, semantic, hybrid }

extension SearchRouteTypeCapabilities on SearchRouteType {
  bool get requiresEmbedding =>
      this == SearchRouteType.semantic || this == SearchRouteType.hybrid;

  bool get appliesStructuredFilters =>
      this == SearchRouteType.structured || this == SearchRouteType.hybrid;
}
