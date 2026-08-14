import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:wara2a/core/utils/invoice_search_text_builder.dart';

import '../ai/fixture_loader.dart';

void main() {
  test(
    'reviewed Arabic, English, and mixed invoices match exact goldens',
    () async {
      final root =
          jsonDecode(
                await loadFixture('search/reviewed_invoice_search_text.json'),
              )
              as Map<String, dynamic>;
      expect(root['schemaVersion'], 1);

      final cases = root['cases'] as List<dynamic>;
      expect(
        cases.map((entry) => (entry as Map<String, dynamic>)['language']),
        containsAll(<String>['ar', 'en', 'ar-en']),
      );

      for (final rawCase in cases) {
        final fixture = rawCase as Map<String, dynamic>;
        final input = fixture['input'] as Map<String, dynamic>;
        final expected = fixture['expected'] as Map<String, dynamic>;
        final items = (input['items'] as List<dynamic>)
            .map((rawItem) {
              final item = rawItem as Map<String, dynamic>;
              return InvoiceSearchItemInput(
                name: item['name'] as String,
                quantity: (item['quantity'] as num?)?.toDouble(),
              );
            })
            .toList(growable: false);

        InvoiceSearchText build() => InvoiceSearchTextBuilder.build(
          merchant: input['merchant'] as String?,
          invoiceNumber: input['invoiceNumber'] as String?,
          purchaseDate: _date(input['purchaseDate']),
          totalMinor: input['totalMinor'] as int?,
          currencyCode: input['currencyCode'] as String?,
          warrantyMonths: input['warrantyMonths'] as int?,
          warrantyEndDate: _date(input['warrantyEndDate']),
          items: items,
        );

        final first = build();
        final second = build();
        final reason = 'fixture ${fixture['id']}';
        expect(
          first.searchableText,
          expected['searchableText'],
          reason: reason,
        );
        expect(first.keywordText, expected['keywordText'], reason: reason);
        expect(second.searchableText, first.searchableText, reason: reason);
        expect(second.keywordText, first.keywordText, reason: reason);
      }
    },
  );
}

DateTime? _date(Object? value) =>
    value == null ? null : DateTime.parse(value as String);
