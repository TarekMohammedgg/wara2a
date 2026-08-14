import 'text_normalization.dart';

class InvoiceSearchItemInput {
  const InvoiceSearchItemInput({required this.name, this.quantity});

  final String name;
  final double? quantity;
}

class InvoiceSearchText {
  const InvoiceSearchText({
    required this.searchableText,
    required this.keywordText,
  });

  final String searchableText;
  final String keywordText;
}

abstract final class InvoiceSearchTextBuilder {
  static const _arabicMonths = <String>[
    'يناير',
    'فبراير',
    'مارس',
    'ابريل',
    'مايو',
    'يونيو',
    'يوليو',
    'اغسطس',
    'سبتمبر',
    'اكتوبر',
    'نوفمبر',
    'ديسمبر',
  ];

  static const _currencyAliases = <String, List<String>>{
    'EGP': ['EGP', 'جنيه', 'جنيه مصري', 'ج م'],
    'USD': ['USD', 'دولار', 'دولار امريكي'],
    'EUR': ['EUR', 'يورو'],
    'SAR': ['SAR', 'ريال', 'ريال سعودي'],
    'AED': ['AED', 'درهم', 'درهم اماراتي'],
    'GBP': ['GBP', 'جنيه استرليني'],
  };

  static const _currencyMinorDigits = <String, int>{
    'BHD': 3,
    'JOD': 3,
    'KWD': 3,
    'OMR': 3,
    'JPY': 0,
  };

  static InvoiceSearchText build({
    String? merchant,
    String? invoiceNumber,
    DateTime? purchaseDate,
    int? totalMinor,
    String? currencyCode,
    int? warrantyMonths,
    DateTime? warrantyEndDate,
    required Iterable<InvoiceSearchItemInput> items,
  }) {
    final cleanMerchant = _clean(merchant);
    final cleanInvoiceNumber = _clean(invoiceNumber);
    final currency = _clean(currencyCode)?.toUpperCase();
    final uniqueItems = _deduplicateItems(items);
    final products = uniqueItems
        .map((item) {
          final quantity = item.quantity;
          return quantity == null
              ? item.name
              : '${item.name} × ${_formatQuantity(quantity)}';
        })
        .join('، ');
    final currencyWords = currency == null
        ? const <String>[]
        : _currencyAliases[currency] ?? <String>[currency];

    final lines = <String>[
      if (cleanMerchant != null) 'المتجر: $cleanMerchant',
      if (cleanInvoiceNumber != null) 'رقم الفاتورة: $cleanInvoiceNumber',
      if (products.isNotEmpty) 'المنتجات: $products',
      if (totalMinor != null)
        'الاجمالي: ${_formatMinor(totalMinor, currency)}'
            '${currencyWords.isEmpty ? '' : ' ${currencyWords.join(' ')}'}',
      if (purchaseDate != null)
        'تاريخ الشراء: ${_isoDate(purchaseDate)}، '
            '${_arabicMonthYear(purchaseDate)}',
      if (warrantyMonths != null || warrantyEndDate != null)
        'الضمان:'
            '${warrantyMonths == null ? '' : ' $warrantyMonths شهر'}'
            '${warrantyEndDate == null ? '' : '${warrantyMonths == null ? ' ' : '، '}ينتهي ${_arabicMonthYear(warrantyEndDate)}'}',
    ];

    final keywordValues = <String?>[
      cleanMerchant,
      cleanInvoiceNumber,
      ...uniqueItems.map((item) => item.name),
      ...currencyWords,
    ];
    final keywordTokens = <String>{};
    for (final value in keywordValues.whereType<String>()) {
      keywordTokens.addAll(
        TextNormalization.normalize(
          value,
        ).split(' ').where((token) => token.isNotEmpty),
      );
    }
    return InvoiceSearchText(
      searchableText: lines.join('\n'),
      keywordText: keywordTokens.isEmpty ? '' : ' ${keywordTokens.join(' ')} ',
    );
  }

  static List<InvoiceSearchItemInput> _deduplicateItems(
    Iterable<InvoiceSearchItemInput> items,
  ) {
    final byName = <String, InvoiceSearchItemInput>{};
    for (final item in items) {
      final name = _clean(item.name);
      if (name == null) continue;
      final key = TextNormalization.normalize(name);
      final existing = byName[key];
      if (existing == null) {
        byName[key] = InvoiceSearchItemInput(
          name: name,
          quantity: item.quantity,
        );
        continue;
      }
      final oldQuantity = existing.quantity;
      final newQuantity = item.quantity;
      byName[key] = InvoiceSearchItemInput(
        name: existing.name,
        quantity: oldQuantity == null
            ? newQuantity
            : newQuantity == null
            ? oldQuantity
            : oldQuantity + newQuantity,
      );
    }
    return List.unmodifiable(byName.values);
  }

  static String? _clean(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return TextNormalization.normalizeNatural(value);
  }

  static String _formatMinor(int value, String? currency) {
    final digits = _currencyMinorDigits[currency] ?? 2;
    if (digits == 0) return value.toString();
    final negative = value < 0;
    final absolute = value.abs();
    final divisor = _pow10(digits);
    final whole = absolute ~/ divisor;
    final fraction = (absolute % divisor).toString().padLeft(digits, '0');
    return '${negative ? '-' : ''}$whole.$fraction';
  }

  static int _pow10(int exponent) {
    var value = 1;
    for (var index = 0; index < exponent; index++) {
      value *= 10;
    }
    return value;
  }

  static String _formatQuantity(double value) {
    if (value == value.truncateToDouble()) return value.toInt().toString();
    return value
        .toStringAsFixed(3)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }

  static String _isoDate(DateTime value) {
    final utc = value.toUtc();
    return '${utc.year.toString().padLeft(4, '0')}-'
        '${utc.month.toString().padLeft(2, '0')}-'
        '${utc.day.toString().padLeft(2, '0')}';
  }

  static String _arabicMonthYear(DateTime value) {
    final utc = value.toUtc();
    return '${_arabicMonths[utc.month - 1]} ${utc.year}';
  }
}
