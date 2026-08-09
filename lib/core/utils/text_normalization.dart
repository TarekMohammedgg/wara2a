abstract final class TextNormalization {
  static final _diacritics = RegExp(
    r'[\u0610-\u061A\u064B-\u065F\u0670\u06D6-\u06ED]',
  );
  static final _whitespace = RegExp(r'\s+');
  static final _keywordPunctuation = RegExp(
    r'[^\u0621-\u063A\u0641-\u064A\u066E-\u06D3\u06FA-\u06FCa-z0-9]+',
  );
  static final _bidiControls = RegExp(
    r'[\u061C\u200E\u200F\u202A-\u202E\u2066-\u2069]',
  );

  static const _digitMap = <String, String>{
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
    return normalizeNatural(
      value,
    ).replaceAll(_keywordPunctuation, ' ').replaceAll(_whitespace, ' ').trim();
  }

  static String normalizeNatural(String value) {
    var normalized = _foldFullWidthAscii(
      value,
    ).toLowerCase().replaceAll(_bidiControls, '').replaceAll('ـ', '');
    normalized = normalized.replaceAll(_diacritics, '');
    normalized = normalized
        .replaceAll(RegExp('[أإآٱ]'), 'ا')
        .replaceAll(RegExp('[ىیۍې]'), 'ي');
    for (final entry in _digitMap.entries) {
      normalized = normalized.replaceAll(entry.key, entry.value);
    }
    return normalized
        .replaceAll('٫', '.')
        .replaceAll('٬', ',')
        .replaceAll(_whitespace, ' ')
        .trim();
  }

  static String normalizeDigits(String value) {
    var normalized = value;
    for (final entry in _digitMap.entries) {
      normalized = normalized.replaceAll(entry.key, entry.value);
    }
    return normalized;
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
