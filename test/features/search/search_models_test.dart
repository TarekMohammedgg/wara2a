import 'package:flutter_test/flutter_test.dart';
import 'package:wara2a/features/search/models/search_filters.dart';
import 'package:wara2a/features/search/models/search_intent.dart';
import 'package:wara2a/features/search/models/search_route_type.dart';

void main() {
  test('filters are immutable, editable, and individually clearable', () {
    const amount = SearchAmountRange(
      minimumMinor: 10000,
      minimumInclusive: false,
    );
    const initial = SearchFilters(amount: amount, currencyCode: 'EGP');

    final edited = initial
        .copyWith(currencyCode: 'USD')
        .clear(SearchFilterField.amount);

    expect(initial.amount, amount);
    expect(initial.currencyCode, 'EGP');
    expect(edited.amount, isNull);
    expect(edited.currencyCode, 'USD');
    expect(edited.activeCount, 1);
  });

  test('amount and half-open date ranges honor their boundaries', () {
    const amount = SearchAmountRange(
      minimumMinor: 10000,
      minimumInclusive: false,
      maximumMinor: 20000,
    );
    final dates = SearchDateRange(
      startInclusive: DateTime.utc(2026, 8),
      endExclusive: DateTime.utc(2026, 9),
    );

    expect(amount.contains(10000), isFalse);
    expect(amount.contains(10001), isTrue);
    expect(amount.contains(20000), isTrue);
    expect(dates.contains(DateTime.utc(2026, 8, 31, 23)), isTrue);
    expect(dates.contains(DateTime.utc(2026, 9)), isFalse);
  });

  test('edited filters derive an appropriate request route', () {
    final intent = SearchIntent(
      rawQuery: 'phone I bought',
      normalizedQuery: 'phone i bought',
      contentQuery: 'phone i bought',
      route: SearchRouteType.semantic,
      filters: const SearchFilters(),
      confidence: 0.82,
    );

    final request = intent.toRequest(
      editedFilters: const SearchFilters(currencyCode: 'EGP'),
    );

    expect(request.route, SearchRouteType.hybrid);
    expect(request.filters.currencyCode, 'EGP');
  });
}
