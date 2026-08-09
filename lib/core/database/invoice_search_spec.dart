import 'invoice_record.dart';

class InvoiceAmountFilter {
  const InvoiceAmountFilter({
    this.minimumMinor,
    this.minimumInclusive = true,
    this.maximumMinor,
    this.maximumInclusive = true,
  }) : assert(minimumMinor != null || maximumMinor != null),
       assert(
         minimumMinor == null ||
             maximumMinor == null ||
             minimumMinor <= maximumMinor,
       );

  final int? minimumMinor;
  final bool minimumInclusive;
  final int? maximumMinor;
  final bool maximumInclusive;
}

class InvoiceDateFilter {
  InvoiceDateFilter({required this.startInclusive, required this.endExclusive})
    : assert(endExclusive.isAfter(startInclusive));

  final DateTime startInclusive;
  final DateTime endExclusive;
}

class InvoiceSearchFilter {
  const InvoiceSearchFilter({
    this.amount,
    this.purchaseDate,
    this.warrantyEndDate,
    this.currencyCode,
    this.documentType,
  });

  final InvoiceAmountFilter? amount;
  final InvoiceDateFilter? purchaseDate;
  final InvoiceDateFilter? warrantyEndDate;
  final String? currencyCode;
  final String? documentType;

  bool get isEmpty =>
      amount == null &&
      purchaseDate == null &&
      warrantyEndDate == null &&
      _isBlank(currencyCode) &&
      _isBlank(documentType);

  bool get isNotEmpty => !isEmpty;
}

class InvoiceKeywordQuery {
  InvoiceKeywordQuery({
    required Iterable<String> normalizedTokens,
    this.filter = const InvoiceSearchFilter(),
    this.limit = 50,
  }) : normalizedTokens = List<String>.unmodifiable(normalizedTokens);

  final List<String> normalizedTokens;
  final InvoiceSearchFilter filter;
  final int limit;
}

class InvoiceVectorQuery {
  InvoiceVectorQuery({
    required Iterable<double> vector,
    required this.modelId,
    required this.dimensions,
    required this.searchTextSchemaVersion,
    required this.embeddingSchemaVersion,
    this.filter = const InvoiceSearchFilter(),
    this.topK = 20,
    this.oversampleFactor = 5,
    this.exactFallbackMaxCandidates = 256,
    this.maximumDistance,
  }) : vector = List<double>.unmodifiable(vector);

  final List<double> vector;
  final String modelId;
  final int dimensions;
  final int searchTextSchemaVersion;
  final int embeddingSchemaVersion;
  final InvoiceSearchFilter filter;
  final int topK;
  final int oversampleFactor;

  /// A metadata-filtered subset at or below this size is ranked with exact
  /// cosine distance. Larger subsets use oversampled HNSW retrieval.
  final int exactFallbackMaxCandidates;

  /// ObjectBox cosine distance threshold. The valid range is 0 through 2 and
  /// lower values are closer.
  final double? maximumDistance;
}

class InvoiceSearchHit {
  const InvoiceSearchHit({required this.record, this.distance});

  final InvoiceRecord record;

  /// ObjectBox cosine distance. Null for keyword and structured-only matches.
  final double? distance;
}

bool _isBlank(String? value) => value == null || value.trim().isEmpty;
