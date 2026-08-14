import 'package:flutter_test/flutter_test.dart';
import 'package:wara2a/features/search/models/search_intent.dart';
import 'package:wara2a/features/search/models/search_intent_router.dart';
import 'package:wara2a/features/search/models/search_route_type.dart';

void main() {
  final router = SearchIntentRouter(clock: () => DateTime.utc(2026, 8, 9, 12));

  test('routes a mixed Latin model name to exact keyword search', () {
    final intent = router.parse('Samsung A56');

    expect(intent.route, SearchRouteType.keyword);
    expect(intent.filters.isEmpty, isTrue);
    expect(intent.contentQuery, 'samsung a56');
  });

  test('parses Arabic-Indic amount and EGP as structured filters', () {
    final intent = router.parse('الفواتير فوق ١٠٠٠٠ جنيه');

    expect(intent.route, SearchRouteType.structured);
    expect(intent.filters.currencyCode, 'EGP');
    expect(intent.filters.amount?.minimumMinor, 1000000);
    expect(intent.filters.amount?.minimumInclusive, isFalse);
    expect(intent.filters.amount?.contains(1000000), isFalse);
    expect(intent.filters.amount?.contains(1000001), isTrue);
  });

  test('parses Persian digits and Egyptian Arabic operator variants', () {
    final intent = router.parse('فواتير اكتر من ۱۰٬۰۰۰ جنيه');

    expect(intent.route, SearchRouteType.structured);
    expect(intent.filters.amount?.minimumMinor, 1000000);
    expect(intent.filters.currencyCode, 'EGP');
  });

  test('parses English inclusive amount operators and currency', () {
    final intent = router.parse('invoices at most 500 USD');

    expect(intent.route, SearchRouteType.structured);
    expect(intent.filters.amount?.maximumMinor, 50000);
    expect(intent.filters.amount?.maximumInclusive, isTrue);
    expect(intent.filters.currencyCode, 'USD');
  });

  test('parses an explicit Arabic month and year as purchase date', () {
    final intent = router.parse('فواتير في أغسطس ٢٠٢٦');

    expect(intent.route, SearchRouteType.structured);
    expect(intent.filters.purchaseDate?.startInclusive, DateTime.utc(2026, 8));
    expect(intent.filters.purchaseDate?.endExclusive, DateTime.utc(2026, 9));
    expect(intent.filters.warrantyEndDate, isNull);
  });

  test('uses the injected clock for a warranty ending this month', () {
    final intent = router.parse('الفواتير اللي ضمانها هيخلص الشهر ده');

    expect(intent.route, SearchRouteType.structured);
    expect(
      intent.filters.warrantyEndDate?.startInclusive,
      DateTime.utc(2026, 8),
    );
    expect(intent.filters.warrantyEndDate?.endExclusive, DateTime.utc(2026, 9));
    expect(intent.filters.purchaseDate, isNull);
  });

  test('parses currency filters', () {
    final intent = router.parse('USD');

    expect(intent.route, SearchRouteType.structured);
    expect(intent.filters.currencyCode, 'USD');
    expect(intent.contentQuery, isEmpty);
  });

  test('uses semantic search for conversational descriptions', () {
    final intent = router.parse('الفاتورة بتاعة الموبايل اللي اشتريته من فترة');

    expect(intent.route, SearchRouteType.semantic);
    expect(intent.filters.isEmpty, isTrue);
  });

  test('uses hybrid only for confident filter plus semantic content', () {
    final intent = router.parse(
      'الفاتورة بتاعة الموبايل اللي اشتريته فوق ١٠٠٠٠ جنيه',
    );

    expect(intent.route, SearchRouteType.hybrid);
    expect(intent.filters.amount, isNotNull);
    expect(intent.filters.currencyCode, 'EGP');
  });

  test('keeps a described model identifier hybrid with a confident filter', () {
    final intent = router.parse(
      'الفاتورة بتاعة Samsung A56 اللي اشتريته فوق ١٠٠٠٠ جنيه',
    );

    expect(intent.route, SearchRouteType.hybrid);
    expect(intent.contentQuery, contains('a56'));
    expect(intent.filters.amount, isNotNull);
  });

  test('does not silently apply an approximate amount filter', () {
    final intent = router.parse('الفواتير حوالي ١٠٠٠٠ جنيه');

    expect(intent.route, SearchRouteType.semantic);
    expect(intent.filters.isEmpty, isTrue);
    expect(intent.issues, contains(SearchParseIssue.ambiguousAmount));
  });

  test(
    'does not silently interpret a warranty month without expiry intent',
    () {
      final intent = router.parse('ضمان في أغسطس');

      expect(intent.filters.warrantyEndDate, isNull);
      expect(intent.filters.purchaseDate, isNull);
      expect(intent.issues, contains(SearchParseIssue.ambiguousWarrantyDate));
    },
  );

  test('rejects a filter below the configured confidence threshold', () {
    final strictRouter = SearchIntentRouter(
      clock: () => DateTime.utc(2026, 8, 9),
      minimumFilterConfidence: 0.9,
    );
    final intent = strictRouter.parse('فواتير في أغسطس');

    expect(intent.filters.purchaseDate, isNull);
    expect(intent.issues, contains(SearchParseIssue.lowConfidenceFilter));
    expect(intent.route, SearchRouteType.semantic);
  });
}
