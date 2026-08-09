abstract final class ArabicQueryNormalizer {
  static final RegExp _diacritics = RegExp(
    r'[\u0610-\u061A\u064B-\u065F\u0670\u06D6-\u06ED]',
  );
  static final RegExp _bidiControls = RegExp(
    r'[\u200E\u200F\u202A-\u202E\u2066-\u2069]',
  );
  static final RegExp _whitespace = RegExp(r'\s+');
  static final RegExp _unsupported = RegExp(
    r'''[^\u0600-\u06FFa-z0-9<>=.,/"'+\-\$€£]+''',
  );

  static const Map<String, String> _digitMap = {
    '٠': '0',
    '١': '1',
    '٢': '2',
    '٣': '3',
    '٤': '4',
    '٥': '5',
    '٦': '6',
    '٧': '7',
    '٨': '8',
    '٩': '9',
    '۰': '0',
    '۱': '1',
    '۲': '2',
    '۳': '3',
    '۴': '4',
    '۵': '5',
    '۶': '6',
    '۷': '7',
    '۸': '8',
    '۹': '9',
  };

  static String normalize(String value) {
    var normalized = _foldFullWidthAscii(value).toLowerCase();
    normalized = normalizeDigits(normalized)
        .replaceAll(_bidiControls, '')
        .replaceAll('ـ', '')
        .replaceAll(_diacritics, '')
        .replaceAll(RegExp('[أإآٱ]'), 'ا')
        .replaceAll('ى', 'ي')
        .replaceAll('ؤ', 'و')
        .replaceAll('ئ', 'ي')
        .replaceAll('٫', '.')
        .replaceAll('٬', ',')
        .replaceAll(RegExp('[،؛؟٪]'), ' ')
        .replaceAll(RegExp('[“”«»]'), '"')
        .replaceAll(RegExp('[‘’]'), "'")
        .replaceAll(RegExp('[–—−]'), '-')
        .replaceAll('≥', '>=')
        .replaceAll('≤', '<=')
        .replaceAll(_unsupported, ' ');
    normalized = normalized.replaceAllMapped(
      RegExp(r'\s*(>=|<=|>|<|=)\s*'),
      (match) => ' ${match.group(1)} ',
    );
    return normalized.replaceAll(_whitespace, ' ').trim();
  }

  static String normalizeForKeyword(String value) {
    return normalize(value)
        .replaceAll(RegExp(r'''[<>=.,/"'+\-\$€£]'''), ' ')
        .replaceAll(_whitespace, ' ')
        .trim();
  }

  static String normalizeDigits(String value) {
    var result = value;
    for (final entry in _digitMap.entries) {
      result = result.replaceAll(entry.key, entry.value);
    }
    return result;
  }

  static String _foldFullWidthAscii(String value) {
    return String.fromCharCodes(
      value.runes.map((rune) {
        if (rune >= 0xFF01 && rune <= 0xFF5E) return rune - 0xFEE0;
        if (rune == 0x3000) return 0x20;
        return rune;
      }),
    );
  }
}
