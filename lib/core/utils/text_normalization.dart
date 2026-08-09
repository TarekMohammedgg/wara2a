abstract final class TextNormalization {
  static final _diacritics = RegExp(
    r'[\u0610-\u061A\u064B-\u065F\u0670\u06D6-\u06ED]',
  );
  static final _whitespace = RegExp(r'\s+');
  static final _punctuation = RegExp(r'[^\u0600-\u06FFa-z0-9]+');

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
    var normalized = value.toLowerCase().replaceAll('ـ', '');
    normalized = normalized.replaceAll(_diacritics, '');
    normalized = normalized
        .replaceAll(RegExp('[أإآٱ]'), 'ا')
        .replaceAll('ى', 'ي');
    for (final entry in _digitMap.entries) {
      normalized = normalized.replaceAll(entry.key, entry.value);
    }
    return normalized
        .replaceAll(_punctuation, ' ')
        .replaceAll(_whitespace, ' ')
        .trim();
  }
}
