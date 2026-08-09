class InvoiceTextNormalizer {
  const InvoiceTextNormalizer._();

  static const Map<String, String> _digits = <String, String>{
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

  static final RegExp _bidiControls = RegExp(
    '[\u061C\u200E\u200F\u202A-\u202E\u2066-\u2069]',
  );
  static final RegExp _whitespace = RegExp(r'\s+');
  static final RegExp _diacritics = RegExp('[\u064B-\u065F\u0670]');

  static String normalizeDigits(String input) {
    final output = StringBuffer();
    for (final rune in input.runes) {
      final character = String.fromCharCode(rune);
      output.write(_digits[character] ?? character);
    }
    return output.toString();
  }

  static String normalizeEvidenceText(String input) {
    return normalizeDigits(input)
        .replaceAll(_bidiControls, '')
        .replaceAll('\u00A0', ' ')
        .replaceAll('ـ', '')
        .replaceAll('٫', '.')
        .replaceAll('٬', ',')
        .replaceAll(_whitespace, ' ')
        .trim();
  }

  static String normalizeForEvidenceMatch(String input) {
    return normalizeEvidenceText(input)
        .replaceAll(_diacritics, '')
        .replaceAll(RegExp('[أإآٱ]'), 'ا')
        .replaceAll('ى', 'ي')
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\u0600-\u06FF.]+'), ' ')
        .replaceAll(_whitespace, ' ')
        .trim();
  }
}

class CurrencyNormalizer {
  const CurrencyNormalizer._();

  static const Map<String, int> supportedMinorUnitDigits = <String, int>{
    'AED': 2,
    'AUD': 2,
    'BHD': 3,
    'CAD': 2,
    'CHF': 2,
    'CNY': 2,
    'DZD': 2,
    'EGP': 2,
    'EUR': 2,
    'GBP': 2,
    'INR': 2,
    'IQD': 3,
    'JOD': 3,
    'JPY': 0,
    'KWD': 3,
    'MAD': 2,
    'OMR': 3,
    'QAR': 2,
    'SAR': 2,
    'TND': 3,
    'TRY': 2,
    'USD': 2,
  };

  static const Map<String, String> _aliases = <String, String>{
    'egp': 'EGP',
    'ج م': 'EGP',
    'ج.م': 'EGP',
    'جنيه': 'EGP',
    'جنيه مصري': 'EGP',
    'جنيها': 'EGP',
    'usd': 'USD',
    r'$': 'USD',
    'دولار': 'USD',
    'eur': 'EUR',
    '€': 'EUR',
    'يورو': 'EUR',
    'sar': 'SAR',
    'ر س': 'SAR',
    'ر.س': 'SAR',
    'ريال سعودي': 'SAR',
    'aed': 'AED',
    'د إ': 'AED',
    'د.إ': 'AED',
    'درهم إماراتي': 'AED',
    'kwd': 'KWD',
    'د ك': 'KWD',
    'د.ك': 'KWD',
    'دينار كويتي': 'KWD',
    'jod': 'JOD',
    'د أ': 'JOD',
    'د.أ': 'JOD',
    'دينار أردني': 'JOD',
    'bhd': 'BHD',
    'د ب': 'BHD',
    'د.ب': 'BHD',
    'دينار بحريني': 'BHD',
    'iqd': 'IQD',
    'د ع': 'IQD',
    'د.ع': 'IQD',
    'دينار عراقي': 'IQD',
    'omr': 'OMR',
    'ر ع': 'OMR',
    'ر.ع': 'OMR',
    'ريال عماني': 'OMR',
    'qar': 'QAR',
    'ر ق': 'QAR',
    'ر.ق': 'QAR',
    'ريال قطري': 'QAR',
    'tnd': 'TND',
    'د ت': 'TND',
    'د.ت': 'TND',
    'دينار تونسي': 'TND',
    'gbp': 'GBP',
    '£': 'GBP',
  };

  static String? normalize(String? value) {
    if (value == null) return null;
    final visible = InvoiceTextNormalizer.normalizeEvidenceText(
      value,
    ).toLowerCase();
    final directAlias = _aliases[visible];
    if (directAlias != null) return directAlias;
    final normalized = InvoiceTextNormalizer.normalizeForEvidenceMatch(value);
    if (normalized.isEmpty) return null;
    final alias = _aliases[normalized];
    if (alias != null) return alias;
    final upper = normalized.toUpperCase();
    if (supportedMinorUnitDigits.containsKey(upper)) return upper;
    return null;
  }

  static bool isSupportedByEvidence(String code, String source) {
    final visible = InvoiceTextNormalizer.normalizeEvidenceText(
      source,
    ).toLowerCase();
    return _aliases.entries
        .where((entry) => entry.value == code)
        .map(
          (entry) => InvoiceTextNormalizer.normalizeEvidenceText(
            entry.key,
          ).toLowerCase(),
        )
        .any(visible.contains);
  }

  static Set<String> evidenceAliases(String code) => _aliases.entries
      .where((entry) => entry.value == code)
      .map(
        (entry) => InvoiceTextNormalizer.normalizeForEvidenceMatch(entry.key),
      )
      .where((alias) => alias.isNotEmpty)
      .toSet();
}

class MoneyNormalizer {
  const MoneyNormalizer._();

  static int fractionDigits(String? currencyCode) =>
      CurrencyNormalizer.supportedMinorUnitDigits[currencyCode] ?? 2;

  static int? majorToMinor(Object? value, {String? currencyCode}) {
    if (value is! num || !value.isFinite || value < 0) return null;
    return decimalStringToMinor(
      value.toString(),
      fractionDigits: fractionDigits(currencyCode),
    );
  }

  static int? decimalStringToMinor(
    String source, {
    required int fractionDigits,
  }) {
    var value = InvoiceTextNormalizer.normalizeEvidenceText(source).trim();
    if (value.contains(RegExp(r'[eE]'))) return null;
    value = value.replaceAll(RegExp(r'[^0-9.,+-]'), '');
    if (value.isEmpty || value.startsWith('-')) {
      return null;
    }
    value = value.replaceAll('+', '');
    final lastDot = value.lastIndexOf('.');
    final lastComma = value.lastIndexOf(',');
    final separator = lastDot > lastComma ? lastDot : lastComma;
    var integerPart = value;
    var fractionPart = '';
    if (separator >= 0) {
      final trailing = value.length - separator - 1;
      final separatorCharacter = value[separator];
      final occurrences = separatorCharacter.allMatches(value).length;
      final otherSeparator = separatorCharacter == '.' ? ',' : '.';
      final looksLikeThousands =
          separatorCharacter == ',' &&
          trailing == 3 &&
          !value.contains(otherSeparator) &&
          (occurrences > 1 || fractionDigits != 3) &&
          (occurrences > 1 || separator <= 3);
      if (!looksLikeThousands && trailing > 0 && trailing <= 6) {
        integerPart = value.substring(0, separator);
        fractionPart = value.substring(separator + 1);
      }
    }
    integerPart = integerPart.replaceAll(RegExp(r'[.,]'), '');
    fractionPart = fractionPart.replaceAll(RegExp(r'[.,]'), '');
    if (integerPart.isEmpty || !RegExp(r'^\d+$').hasMatch(integerPart)) {
      return null;
    }
    if (fractionPart.isNotEmpty && !RegExp(r'^\d+$').hasMatch(fractionPart)) {
      return null;
    }
    if (fractionPart.length > fractionDigits) {
      final discarded = fractionPart.substring(fractionDigits);
      if (discarded.runes.any((rune) => rune != 48)) return null;
      fractionPart = fractionPart.substring(0, fractionDigits);
    }
    fractionPart = fractionPart.padRight(fractionDigits, '0');
    final major = int.tryParse(integerPart);
    final fraction = fractionPart.isEmpty ? 0 : int.tryParse(fractionPart);
    if (major == null || fraction == null) return null;
    final multiplier = _pow10(fractionDigits);
    if (major > 1000000000000 ||
        major > (0x7FFFFFFFFFFFFFFF - fraction) ~/ multiplier) {
      return null;
    }
    return major * multiplier + fraction;
  }

  static Set<int> extractMinorAmounts(String source, {String? currencyCode}) {
    return extractScaledNumbers(
      source,
      fractionDigits: fractionDigits(currencyCode),
    );
  }

  static Set<int> extractScaledNumbers(
    String source, {
    required int fractionDigits,
  }) {
    final normalized = InvoiceTextNormalizer.normalizeEvidenceText(source);
    final matches = RegExp(
      r'(?<!\d)(?:\d{1,3}(?:[,.]\d{3})+|\d+)(?:[,.]\d{1,3})?(?!\d)',
    ).allMatches(normalized);
    return matches
        .map(
          (match) => decimalStringToMinor(
            match.group(0)!,
            fractionDigits: fractionDigits,
          ),
        )
        .whereType<int>()
        .toSet();
  }

  static int _pow10(int exponent) {
    var result = 1;
    for (var i = 0; i < exponent; i++) {
      result *= 10;
    }
    return result;
  }
}

class InvoiceDateNormalizer {
  const InvoiceDateNormalizer._();

  static const Map<String, int> _arabicMonths = <String, int>{
    'يناير': 1,
    'فبراير': 2,
    'مارس': 3,
    'ابريل': 4,
    'أبريل': 4,
    'مايو': 5,
    'يونيو': 6,
    'يوليو': 7,
    'اغسطس': 8,
    'أغسطس': 8,
    'سبتمبر': 9,
    'اكتوبر': 10,
    'أكتوبر': 10,
    'نوفمبر': 11,
    'ديسمبر': 12,
  };

  static DateTime? parseIsoDate(Object? value) {
    if (value is! String || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
      return null;
    }
    final parts = value.split('-').map(int.parse).toList(growable: false);
    return _checkedDate(parts[0], parts[1], parts[2]);
  }

  static Set<DateTime> extractDates(String source) {
    final normalized = InvoiceTextNormalizer.normalizeEvidenceText(source);
    final dates = <DateTime>{};
    final numeric = RegExp(
      r'(?<!\d)(\d{1,4})[-/.](\d{1,2})[-/.](\d{1,4})(?!\d)',
    );
    for (final match in numeric.allMatches(normalized)) {
      final first = int.parse(match.group(1)!);
      final second = int.parse(match.group(2)!);
      final third = int.parse(match.group(3)!);
      final date = first > 31
          ? _checkedDate(first, second, third)
          : _checkedDate(_expandYear(third), second, first);
      if (date != null) dates.add(date);
    }
    for (final entry in _arabicMonths.entries) {
      final expression = RegExp(
        '(?<!\\d)(\\d{1,2})\\s+${RegExp.escape(entry.key)}\\s+(\\d{2,4})(?!\\d)',
      );
      for (final match in expression.allMatches(normalized)) {
        final date = _checkedDate(
          _expandYear(int.parse(match.group(2)!)),
          entry.value,
          int.parse(match.group(1)!),
        );
        if (date != null) dates.add(date);
      }
    }
    return dates;
  }

  static int _expandYear(int year) => year < 100 ? 2000 + year : year;

  static DateTime? _checkedDate(int year, int month, int day) {
    if (year < 1900 ||
        year > 2100 ||
        month < 1 ||
        month > 12 ||
        day < 1 ||
        day > 31) {
      return null;
    }
    final date = DateTime.utc(year, month, day);
    if (date.year != year || date.month != month || date.day != day) {
      return null;
    }
    return date;
  }
}
