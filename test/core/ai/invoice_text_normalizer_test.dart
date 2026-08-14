import 'package:flutter_test/flutter_test.dart';
import 'package:wara2a/core/ai/extraction/invoice_text_normalizer.dart';

void main() {
  group('InvoiceTextNormalizer', () {
    test('normalizes Arabic-Indic and Persian digits deterministically', () {
      expect(
        InvoiceTextNormalizer.normalizeDigits('٠١٢٣٤٥٦٧٨٩ ۰۱۲۳۴۵۶۷۸۹'),
        '0123456789 0123456789',
      );
    });

    test('removes bidi controls without mutating Arabic letters', () {
      expect(
        InvoiceTextNormalizer.normalizeEvidenceText(
          '\u200Fالإجمالي\u202E ٢٤٬٩٩٩٫٥٠',
        ),
        'الإجمالي 24,999.50',
      );
    });
  });

  group('MoneyNormalizer', () {
    test('converts Arabic and grouped money to exact minor units', () {
      expect(
        MoneyNormalizer.decimalStringToMinor('٢٤٬٩٩٩٫٥٠', fractionDigits: 2),
        2499950,
      );
      expect(
        MoneyNormalizer.decimalStringToMinor('24,999.00', fractionDigits: 2),
        2499900,
      );
      expect(
        MoneyNormalizer.extractMinorAmounts('الإجمالي 12,50 ج.م'),
        contains(1250),
      );
      expect(
        MoneyNormalizer.decimalStringToMinor('24.999,00', fractionDigits: 2),
        2499900,
      );
      expect(MoneyNormalizer.majorToMinor(1.234, currencyCode: 'JOD'), 1234);
    });

    test('rejects negatives, precision loss, and scientific notation', () {
      expect(
        MoneyNormalizer.decimalStringToMinor('-1', fractionDigits: 2),
        isNull,
      );
      expect(
        MoneyNormalizer.decimalStringToMinor('1.009', fractionDigits: 2),
        isNull,
      );
      expect(
        MoneyNormalizer.decimalStringToMinor('1e4', fractionDigits: 2),
        isNull,
      );
    });
  });

  test('extracts Arabic-numeral invoice dates', () {
    final dates = InvoiceDateNormalizer.extractDates('تاريخ الشراء ٠٩/٠٨/٢٠٢٦');
    expect(dates, contains(DateTime.utc(2026, 8, 9)));
  });

  test('extracts spaced and compact numeric dates', () {
    expect(
      InvoiceDateNormalizer.extractDates('التاريخ 2024 05 28'),
      contains(DateTime.utc(2024, 5, 28)),
    );
    expect(
      InvoiceDateNormalizer.extractDates('20240528'),
      contains(DateTime.utc(2024, 5, 28)),
    );
  });

  test('keeps ambiguous Arabic currency abbreviations distinct', () {
    expect(CurrencyNormalizer.normalize('د.أ'), 'JOD');
    expect(CurrencyNormalizer.normalize('د.إ'), 'AED');
    expect(CurrencyNormalizer.normalize('XYZ'), isNull);
  });
}
