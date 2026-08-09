import 'dart:convert';
import 'dart:io';

const _corpusVersion = 'wara2a-eval-2026-08-09-v1';

const _merchants = <String>[
  'نقطة تك',
  'Cairo Byte',
  'ورقة موبايل',
  'Delta Devices',
  'سوق النور',
  'Nile Circuit',
  'بيت الشاشة',
  'Alex Gadget Lab',
  'مخزن بكسل',
  'Orbit Office',
];

const _products = <String>[
  'هاتف نوفا',
  'Nova Phone',
  'سماعة موجة',
  'Wave Headset',
  'شاحن برق',
  'Spark Charger',
  'لوحة مفاتيح سطر',
  'Line Keyboard',
  'شاشة أفق',
  'Horizon Display',
];

const _currencies = <String>['EGP', 'SAR', 'AED', 'USD', 'EUR', 'JOD'];
const _documentTypes = <String>['فاتورة شراء', 'Purchase Invoice'];
const _glare = <String>['none', 'mild', 'strong'];
const _contrast = <String>['normal', 'low'];
const _digitScripts = <String>['latin', 'arabic-indic', 'persian'];
const _dateStyles = <String>['iso', 'arabic-slash', 'persian-slash'];
const _skewDegrees = <double>[-4.5, -2.0, 0.0, 2.0, 4.5];

void main() {
  final outputDirectory = Directory('test/fixtures/evaluation');
  outputDirectory.createSync(recursive: true);

  final invoices = _buildInvoices();
  final queries = _buildQueries(invoices);
  _writeJsonLines(File('${outputDirectory.path}/invoices.jsonl'), invoices);
  _writeJsonLines(
    File('${outputDirectory.path}/search_queries.jsonl'),
    queries,
  );
}

List<Map<String, Object?>> _buildInvoices() {
  final start = DateTime.utc(2026, 1, 6);
  return List<Map<String, Object?>>.generate(50, (index) {
    final number = index + 1;
    final language = switch (index % 3) {
      0 => 'ar',
      1 => 'en',
      _ => 'mixed',
    };
    final layout = index.isEven ? 'thermal' : 'a4';
    final digits = _digitScripts[index % _digitScripts.length];
    final purchaseDate = start.add(Duration(days: index * 7));
    final date = _dateOnly(purchaseDate);
    final currency = _currencies[index % _currencies.length];
    final total = 875.0 + (index * 137.5);
    final warrantyMonths = index % 10 == 9 ? null : 3 + ((index * 3) % 21);
    final obscuredFields = <String>[];
    final nullFields = <String>[];
    switch (index % 6) {
      case 0:
        obscuredFields.add('total');
      case 1:
        obscuredFields.add('purchaseDate');
      case 2:
        obscuredFields.add('currency');
      case 3:
        if (warrantyMonths == null) {
          nullFields.add('warrantyMonths');
        } else {
          obscuredFields.add('warrantyMonths');
        }
      case 4:
        obscuredFields.add('products[0].lineTotal');
      case 5:
        break;
    }

    final merchant =
        '${_merchants[index % _merchants.length]} ${_digits(number, digits)}';
    final product =
        '${_products[index % _products.length]}-${_digits(number, digits)}';
    final invoiceNumber = 'SYN-${number.toString().padLeft(3, '0')}';
    final documentType = _documentTypes[index % _documentTypes.length];
    final sourceDate = _formatDate(
      purchaseDate,
      digits,
      _dateStyles[index % _dateStyles.length],
    );
    final sourceTotal = _formatAmount(total, digits);
    final sourceCurrency = obscuredFields.contains('currency')
        ? '<obscured>'
        : currency;
    final sourceDateValue = obscuredFields.contains('purchaseDate')
        ? '<obscured>'
        : sourceDate;
    final sourceTotalValue = obscuredFields.contains('total')
        ? '<obscured>'
        : sourceTotal;
    final sourceWarranty = warrantyMonths == null
        ? '<absent>'
        : obscuredFields.contains('warrantyMonths')
        ? '<obscured>'
        : '${_digits(warrantyMonths, digits)} months';
    final sourceLines = <String>[
      language == 'ar' ? merchant : '$merchant | Wara2a Store',
      '$documentType | No. $invoiceNumber',
      language == 'en' ? 'Date: $sourceDateValue' : 'التاريخ: $sourceDateValue',
      language == 'en'
          ? 'Item: $product x ${_digits(1, digits)}'
          : 'الصنف: $product × ${_digits(1, digits)}',
      language == 'en'
          ? 'Total: $sourceTotalValue $sourceCurrency'
          : 'الإجمالي: $sourceTotalValue $sourceCurrency',
      language == 'en'
          ? 'Warranty: $sourceWarranty'
          : 'الضمان: $sourceWarranty',
    ];

    return <String, Object?>{
      'corpusVersion': _corpusVersion,
      'caseId': 'invoice-${number.toString().padLeft(3, '0')}',
      'language': language,
      'layout': layout,
      'source': <String, Object?>{
        'kind': 'synthetic-text-render-spec',
        'renderId': 'render-invoice-${number.toString().padLeft(3, '0')}',
        'imageWidth': layout == 'thermal' ? 1080 : 1654,
        'imageHeight': layout == 'thermal' ? 1920 : 2339,
        'digitScript': digits,
        'dateStyle': _dateStyles[index % _dateStyles.length],
        'textLines': sourceLines,
      },
      'conditions': <String, Object?>{
        'glare': _glare[index % _glare.length],
        'skewDegrees': _skewDegrees[index % _skewDegrees.length],
        'contrast': _contrast[index % _contrast.length],
        'occlusion': obscuredFields.isEmpty ? 'none' : 'partial',
      },
      'obscuredFields': obscuredFields,
      'nullFields': nullFields,
      'expected': <String, Object?>{
        'merchant': merchant,
        'documentType': documentType,
        'purchaseDate': obscuredFields.contains('purchaseDate') ? null : date,
        'total': obscuredFields.contains('total') ? null : total,
        'currency': obscuredFields.contains('currency') ? null : currency,
        'products': <Object?>[
          <String, Object?>{
            'name': product,
            'quantity': 1,
            'unitPrice': total,
            'lineTotal': obscuredFields.contains('products[0].lineTotal')
                ? null
                : total,
          },
        ],
        'warrantyMonths':
            obscuredFields.contains('warrantyMonths') || warrantyMonths == null
            ? null
            : warrantyMonths,
        'rawText': sourceLines.join('\n'),
      },
      'search': <String, Object?>{
        'invoiceNumber': invoiceNumber,
        'merchant': merchant,
        'product': product,
        'purchaseDate': date,
        'currency': currency,
        'documentType': documentType,
        'warrantyEndDate': warrantyMonths == null
            ? null
            : _dateOnly(
                DateTime.utc(
                  purchaseDate.year,
                  purchaseDate.month + warrantyMonths,
                  purchaseDate.day,
                ),
              ),
      },
    };
  });
}

List<Map<String, Object?>> _buildQueries(List<Map<String, Object?>> invoices) {
  final queries = <Map<String, Object?>>[];
  for (var index = 0; index < 25; index++) {
    final invoice = invoices[index];
    final search = invoice['search']! as Map<String, Object?>;
    final mixed = index.isOdd;
    queries.add(
      _query(
        index + 1,
        mixed
            ? 'invoice ${search['invoiceNumber']} de ${search['merchant']}'
            : 'رقم الفاتورة ${search['invoiceNumber']} من ${search['merchant']}',
        mixed ? 'mixed' : 'ar',
        'keyword',
        invoice['caseId']! as String,
        <String, Object?>{},
      ),
    );
  }

  for (var index = 0; index < 25; index++) {
    final invoice = invoices[25 + index];
    final search = invoice['search']! as Map<String, Object?>;
    final filterType = index % 5;
    final filters = <String, Object?>{};
    late String text;
    switch (filterType) {
      case 0:
        final total =
            (invoice['expected']! as Map<String, Object?>)['total'] as num?;
        filters['amount'] = <String, Object?>{
          'operator': 'gte',
          'minor': ((total ?? 0) * 100).round(),
        };
        text =
            'فواتير فوق ${_formatAmount(total ?? 0, _digitScripts[index % 3])} ${search['currency']}';
      case 1:
        filters['dateRange'] = <String, Object?>{
          'from': search['purchaseDate'],
          'to': search['purchaseDate'],
        };
        text = 'فاتورة في تاريخ ${search['purchaseDate']}';
      case 2:
        filters['currencyCode'] = search['currency'];
        text = 'الفواتير بعملة ${search['currency']}';
      case 3:
        filters['documentType'] = search['documentType'];
        text = 'اعرض ${search['documentType']}';
      default:
        final warranty = search['warrantyEndDate'];
        if (warranty == null) {
          filters['documentType'] = search['documentType'];
          text = 'فواتير ${search['documentType']} بدون موعد ضمان';
        } else {
          filters['warrantyEndDate'] = warranty;
          text = 'الضمان ينتهي في ${warranty.toString().substring(0, 7)}';
        }
    }
    queries.add(
      _query(
        26 + index,
        text,
        index.isOdd ? 'mixed' : 'ar',
        'structured',
        invoice['caseId']! as String,
        filters,
      ),
    );
  }

  for (var index = 0; index < 25; index++) {
    final invoice = invoices[index + 25];
    final search = invoice['search']! as Map<String, Object?>;
    final text = index.isOdd
        ? 'عايز invoice بتاعة ${search['product']} من ${search['merchant']}'
        : 'الفاتورة الخاصة بـ ${search['product']} من ${search['merchant']}';
    queries.add(
      _query(
        51 + index,
        text,
        index.isOdd ? 'mixed' : 'ar',
        'semantic',
        invoice['caseId']! as String,
        <String, Object?>{},
      ),
    );
  }

  for (var index = 0; index < 25; index++) {
    final invoice = invoices[index];
    final search = invoice['search']! as Map<String, Object?>;
    final filters = <String, Object?>{'currencyCode': search['currency']};
    final text = index.isOdd
        ? 'عايز ${search['product']} بضمان، invoice بعملة ${search['currency']}'
        : '${search['product']} بضمان بعملة ${search['currency']}';
    queries.add(
      _query(
        76 + index,
        text,
        index.isOdd ? 'mixed' : 'ar',
        'hybrid',
        invoice['caseId']! as String,
        filters,
      ),
    );
  }
  return queries;
}

Map<String, Object?> _query(
  int number,
  String text,
  String language,
  String route,
  String invoiceId,
  Map<String, Object?> filters,
) => <String, Object?>{
  'corpusVersion': _corpusVersion,
  'queryId': 'query-${number.toString().padLeft(3, '0')}',
  'text': text,
  'language': language,
  'expectedRoute': route,
  'expectedInvoiceIds': <String>[invoiceId],
  'filters': filters,
};

String _dateOnly(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

String _formatDate(DateTime date, String digitScript, String style) {
  final year = _digits(date.year, digitScript);
  final month = _digits(date.month.toString().padLeft(2, '0'), digitScript);
  final day = _digits(date.day.toString().padLeft(2, '0'), digitScript);
  return switch (style) {
    'arabic-slash' => '$day/$month/$year',
    'persian-slash' => '$year/$month/$day',
    _ => '$year-$month-$day',
  };
}

String _formatAmount(num amount, String digitScript) {
  final text = amount.toStringAsFixed(2);
  return _digits(text, digitScript);
}

String _digits(Object value, String digitScript) {
  final text = value.toString();
  if (digitScript == 'latin') return text;
  const arabicIndic = '٠١٢٣٤٥٦٧٨٩';
  const persian = '۰۱۲۳۴۵۶۷۸۹';
  final target = digitScript == 'persian' ? persian : arabicIndic;
  return text.split('').map((character) {
    final digit = int.tryParse(character);
    return digit == null ? character : target[digit];
  }).join();
}

void _writeJsonLines(File file, List<Map<String, Object?>> records) {
  file.writeAsStringSync(
    '${records.map(jsonEncode).join('\n')}\n',
    flush: true,
  );
}
