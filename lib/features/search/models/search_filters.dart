import 'package:equatable/equatable.dart';

enum SearchFilterField { amount, purchaseDate, warrantyEndDate, currency }

class SearchAmountRange extends Equatable {
  const SearchAmountRange({
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

  bool contains(int valueMinor) {
    final minimum = minimumMinor;
    if (minimum != null &&
        (minimumInclusive ? valueMinor < minimum : valueMinor <= minimum)) {
      return false;
    }
    final maximum = maximumMinor;
    if (maximum != null &&
        (maximumInclusive ? valueMinor > maximum : valueMinor >= maximum)) {
      return false;
    }
    return true;
  }

  @override
  List<Object?> get props => [
    minimumMinor,
    minimumInclusive,
    maximumMinor,
    maximumInclusive,
  ];
}

class SearchDateRange extends Equatable {
  SearchDateRange({required this.startInclusive, required this.endExclusive})
    : assert(endExclusive.isAfter(startInclusive));

  final DateTime startInclusive;
  final DateTime endExclusive;

  bool contains(DateTime value) =>
      !value.isBefore(startInclusive) && value.isBefore(endExclusive);

  @override
  List<Object?> get props => [startInclusive, endExclusive];
}

class SearchFilters extends Equatable {
  const SearchFilters({
    this.amount,
    this.purchaseDate,
    this.warrantyEndDate,
    this.currencyCode,
  });

  final SearchAmountRange? amount;
  final SearchDateRange? purchaseDate;
  final SearchDateRange? warrantyEndDate;
  final String? currencyCode;

  bool get isEmpty => activeCount == 0;
  bool get isNotEmpty => !isEmpty;

  int get activeCount => [
    amount,
    purchaseDate,
    warrantyEndDate,
    currencyCode,
  ].where((value) => value != null).length;

  SearchFilters copyWith({
    SearchAmountRange? amount,
    SearchDateRange? purchaseDate,
    SearchDateRange? warrantyEndDate,
    String? currencyCode,
    bool clearAmount = false,
    bool clearPurchaseDate = false,
    bool clearWarrantyEndDate = false,
    bool clearCurrency = false,
  }) {
    return SearchFilters(
      amount: clearAmount ? null : amount ?? this.amount,
      purchaseDate: clearPurchaseDate
          ? null
          : purchaseDate ?? this.purchaseDate,
      warrantyEndDate: clearWarrantyEndDate
          ? null
          : warrantyEndDate ?? this.warrantyEndDate,
      currencyCode: clearCurrency ? null : currencyCode ?? this.currencyCode,
    );
  }

  SearchFilters clear(SearchFilterField field) {
    return switch (field) {
      SearchFilterField.amount => copyWith(clearAmount: true),
      SearchFilterField.purchaseDate => copyWith(clearPurchaseDate: true),
      SearchFilterField.warrantyEndDate => copyWith(clearWarrantyEndDate: true),
      SearchFilterField.currency => copyWith(clearCurrency: true),
    };
  }

  @override
  List<Object?> get props => [
    amount,
    purchaseDate,
    warrantyEndDate,
    currencyCode,
  ];
}
