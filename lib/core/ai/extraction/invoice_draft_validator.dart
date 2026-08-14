import 'dart:convert';

import '../../../features/invoice_capture/models/invoice_draft.dart';
import 'invoice_text_normalizer.dart';

enum DraftValidationCode {
  emptyOutput,
  invalidJson,
  rootNotObject,
  unknownKey,
  missingKey,
  invalidType,
  invalidString,
  invalidDate,
  invalidMoney,
  invalidCurrency,
  invalidQuantity,
  invalidWarranty,
  tooManyProducts,
  inconsistentArithmetic,
}

class DraftValidationIssue {
  const DraftValidationIssue({
    required this.code,
    required this.path,
    required this.message,
  });

  final DraftValidationCode code;
  final String path;
  final String message;

  Map<String, String> toPromptJson() => <String, String>{
    'code': code.name,
    'path': path,
    'message': message,
  };
}

class DraftValidationResult {
  const DraftValidationResult({required this.issues, this.draft});

  final InvoiceDraft? draft;
  final List<DraftValidationIssue> issues;

  bool get isValid => draft != null && issues.isEmpty;
}

class InvoiceDraftValidator {
  const InvoiceDraftValidator({
    this.maxProducts = 100,
    this.maxStringLength = 500,
  });

  static const Set<String> _rootKeys = <String>{
    'merchant',
    'purchaseDate',
    'invoiceNumber',
    'total',
    'currency',
    'products',
    'warrantyMonths',
    'rawText',
  };
  static const Set<String> _productKeys = <String>{
    'name',
    'quantity',
    'unitPrice',
    'lineTotal',
  };

  final int maxProducts;
  final int maxStringLength;

  DraftValidationResult validate({
    required String modelOutput,
    required InvoiceDraftOrigin origin,
  }) {
    final issues = <DraftValidationIssue>[];
    final trimmed = modelOutput.trim();
    if (trimmed.isEmpty) {
      return const DraftValidationResult(
        issues: <DraftValidationIssue>[
          DraftValidationIssue(
            code: DraftValidationCode.emptyOutput,
            path: r'$',
            message: 'Return exactly one JSON object.',
          ),
        ],
      );
    }

    Object? decoded;
    try {
      decoded = jsonDecode(trimmed);
    } on FormatException catch (error) {
      return DraftValidationResult(
        issues: <DraftValidationIssue>[
          DraftValidationIssue(
            code: DraftValidationCode.invalidJson,
            path: r'$',
            message: 'Invalid JSON: ${error.message}',
          ),
        ],
      );
    }
    if (decoded is! Map) {
      return const DraftValidationResult(
        issues: <DraftValidationIssue>[
          DraftValidationIssue(
            code: DraftValidationCode.rootNotObject,
            path: r'$',
            message: 'The response must be one JSON object.',
          ),
        ],
      );
    }
    final root = <String, Object?>{
      for (final entry in decoded.entries) entry.key.toString(): entry.value,
    };
    // Legacy model outputs may still include this retired field.
    root.remove('documentType');
    _validateKeys(root, _rootKeys, r'$', issues);

    final merchant = _nullableString(root['merchant'], r'$.merchant', issues);
    final purchaseDateValue = root['purchaseDate'];
    DateTime? purchaseDate;
    if (purchaseDateValue != null) {
      purchaseDate = InvoiceDateNormalizer.parseIsoDate(purchaseDateValue);
      if (purchaseDate == null) {
        issues.add(
          const DraftValidationIssue(
            code: DraftValidationCode.invalidDate,
            path: r'$.purchaseDate',
            message:
                'Use a real ISO-8601 calendar date in YYYY-MM-DD form or null.',
          ),
        );
      }
    }

    var invoiceNumber = _nullableString(
      root['invoiceNumber'],
      r'$.invoiceNumber',
      issues,
      maxLength: 128,
    );

    final currencyValue = _nullableString(
      root['currency'],
      r'$.currency',
      issues,
      maxLength: 32,
    );
    var currencyCode = CurrencyNormalizer.normalize(currencyValue);
    var currency = currencyCode ?? currencyValue;

    final totalValue = root['total'];
    int? totalMinor;
    if (totalValue != null) {
      totalMinor = MoneyNormalizer.majorToMinor(
        totalValue,
        currencyCode: currencyCode,
      );
      if (totalMinor == null) {
        issues.add(
          const DraftValidationIssue(
            code: DraftValidationCode.invalidMoney,
            path: r'$.total',
            message:
                'Total must be a finite non-negative JSON number within bounds.',
          ),
        );
      }
    }

    final products = <InvoiceItemDraft>[];
    final productsValue = root['products'];
    if (productsValue is! List) {
      issues.add(
        const DraftValidationIssue(
          code: DraftValidationCode.invalidType,
          path: r'$.products',
          message: 'Products must be a JSON array.',
        ),
      );
    } else if (productsValue.length > maxProducts) {
      issues.add(
        DraftValidationIssue(
          code: DraftValidationCode.tooManyProducts,
          path: r'$.products',
          message: 'Products may contain at most $maxProducts items.',
        ),
      );
    } else {
      for (var index = 0; index < productsValue.length; index++) {
        final item = productsValue[index];
        final path = '\$.products[$index]';
        if (item is! Map) {
          issues.add(
            DraftValidationIssue(
              code: DraftValidationCode.invalidType,
              path: path,
              message: 'Each product must be a JSON object.',
            ),
          );
          continue;
        }
        final productMap = <String, Object?>{
          for (final entry in item.entries) entry.key.toString(): entry.value,
        };
        _validateKeys(productMap, _productKeys, path, issues);
        final name = _nullableString(productMap['name'], '$path.name', issues);
        final quantity = _nullableQuantity(
          productMap['quantity'],
          '$path.quantity',
          issues,
        );
        final unitPriceMinor = _nullableMoney(
          productMap['unitPrice'],
          '$path.unitPrice',
          currencyCode,
          issues,
        );
        final lineTotalMinor = _nullableMoney(
          productMap['lineTotal'],
          '$path.lineTotal',
          currencyCode,
          issues,
        );
        if (quantity != null &&
            unitPriceMinor != null &&
            lineTotalMinor != null) {
          final expected = (quantity * unitPriceMinor).round();
          if ((expected - lineTotalMinor).abs() > 1) {
            issues.add(
              DraftValidationIssue(
                code: DraftValidationCode.inconsistentArithmetic,
                path: path,
                message: 'quantity Ã— unitPrice does not equal lineTotal.',
              ),
            );
          }
        }
        products.add(
          InvoiceItemDraft(
            name: name,
            quantity: quantity,
            unitPriceMinor: unitPriceMinor,
            lineTotalMinor: lineTotalMinor,
          ),
        );
      }
    }

    final warrantyValue = root['warrantyMonths'];
    int? warrantyMonths;
    if (warrantyValue != null) {
      if (warrantyValue is int && warrantyValue >= 0 && warrantyValue <= 1200) {
        warrantyMonths = warrantyValue;
      } else {
        issues.add(
          const DraftValidationIssue(
            code: DraftValidationCode.invalidWarranty,
            path: r'$.warrantyMonths',
            message:
                'Warranty months must be an integer from 0 through 1200 or null.',
          ),
        );
      }
    }
    final hasMoney =
        totalValue != null ||
        products.any(
          (product) =>
              product.unitPriceMinor != null || product.lineTotalMinor != null,
        );
    if (hasMoney && currencyCode == null) {
      issues.add(
        const DraftValidationIssue(
          code: DraftValidationCode.invalidCurrency,
          path: r'$.currency',
          message:
              'A supported currency is required before money can be converted to exact minor units.',
        ),
      );
    }
    final modelRawText = _nullableString(
      root['rawText'],
      r'$.rawText',
      issues,
      maxLength: 20000,
    );

    if (issues.isEmpty) {
      _rejectInconsistentArithmetic(products, totalMinor, issues);
    }
    if (issues.isNotEmpty) {
      return DraftValidationResult(issues: List.unmodifiable(issues));
    }
    return DraftValidationResult(
      issues: const <DraftValidationIssue>[],
      draft: InvoiceDraft(
        merchant: merchant,
        purchaseDate: purchaseDate,
        invoiceNumber: invoiceNumber,
        totalMinor: totalMinor,
        currency: currency,
        products: products,
        warrantyMonths: warrantyMonths,
        rawText: modelRawText ?? '',
        origin: origin,
        requiresManualReview: true,
      ),
    );
  }

  void _validateKeys(
    Map<String, Object?> value,
    Set<String> allowed,
    String path,
    List<DraftValidationIssue> issues,
  ) {
    for (final key in value.keys.where((key) => !allowed.contains(key))) {
      issues.add(
        DraftValidationIssue(
          code: DraftValidationCode.unknownKey,
          path: '$path.$key',
          message: 'Unknown keys are forbidden.',
        ),
      );
    }
    for (final key in allowed.where((key) => !value.containsKey(key))) {
      issues.add(
        DraftValidationIssue(
          code: DraftValidationCode.missingKey,
          path: '$path.$key',
          message: 'Every schema key must be present; use null when unknown.',
        ),
      );
    }
  }

  String? _nullableString(
    Object? value,
    String path,
    List<DraftValidationIssue> issues, {
    int? maxLength,
  }) {
    if (value == null) return null;
    if (value is! String) {
      issues.add(
        DraftValidationIssue(
          code: DraftValidationCode.invalidType,
          path: path,
          message: 'Value must be a string or null.',
        ),
      );
      return null;
    }
    final trimmed = value.trim();
    if (trimmed.isEmpty || trimmed.length > (maxLength ?? maxStringLength)) {
      issues.add(
        DraftValidationIssue(
          code: DraftValidationCode.invalidString,
          path: path,
          message:
              'String must be non-empty and within the field length limit.',
        ),
      );
      return null;
    }
    return trimmed;
  }

  double? _nullableQuantity(
    Object? value,
    String path,
    List<DraftValidationIssue> issues,
  ) {
    if (value == null) return null;
    if (value is! num || !value.isFinite || value < 0 || value > 1000000) {
      issues.add(
        DraftValidationIssue(
          code: DraftValidationCode.invalidQuantity,
          path: path,
          message:
              'Quantity must be a finite non-negative number within bounds.',
        ),
      );
      return null;
    }
    return value.toDouble();
  }

  int? _nullableMoney(
    Object? value,
    String path,
    String? currencyCode,
    List<DraftValidationIssue> issues,
  ) {
    if (value == null) return null;
    final minor = MoneyNormalizer.majorToMinor(
      value,
      currencyCode: currencyCode,
    );
    if (minor == null) {
      issues.add(
        DraftValidationIssue(
          code: DraftValidationCode.invalidMoney,
          path: path,
          message:
              'Money must be a finite non-negative JSON number within bounds.',
        ),
      );
    }
    return minor;
  }

  void _rejectInconsistentArithmetic(
    List<InvoiceItemDraft> products,
    int? totalMinor,
    List<DraftValidationIssue> issues,
  ) {
    final lineTotals = products
        .map((product) => product.lineTotalMinor)
        .whereType<int>();
    if (totalMinor == null ||
        lineTotals.length != products.length ||
        products.isEmpty) {
      return;
    }
    final sum = lineTotals.fold<int>(0, (total, value) => total + value);
    if (sum > totalMinor) {
      issues.add(
        const DraftValidationIssue(
          code: DraftValidationCode.inconsistentArithmetic,
          path: r'$.products',
          message: 'The sum of line totals is greater than the invoice total.',
        ),
      );
    }
  }
}
