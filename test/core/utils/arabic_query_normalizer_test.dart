import 'package:flutter_test/flutter_test.dart';
import 'package:wara2a/core/utils/arabic_query_normalization/arabic_query_normalizer.dart';

void main() {
  test('normalizes Arabic variants, marks, punctuation, and digits', () {
    expect(
      ArabicQueryNormalizer.normalize('  أَكْثَر مِن ١٢٬٣٤٥٫٦٠ جُنَيْه؟  '),
      'اكثر من 12,345.60 جنيه',
    );
  });

  test('normalizes Persian and full-width digits deterministically', () {
    expect(
      ArabicQueryNormalizer.normalize('Samsung Ａ５６ فوق ۱۲۳'),
      'samsung a56 فوق 123',
    );
  });

  test('creates keyword-compatible invoice identifiers', () {
    expect(ArabicQueryNormalizer.normalizeForKeyword('BT-١٢٣/أ'), 'bt 123 ا');
  });
}
