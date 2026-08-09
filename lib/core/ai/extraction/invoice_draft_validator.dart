import 'dart:convert';

import '../../../features/invoice_capture/models/invoice_draft.dart';
import '../ocr/ocr_evidence.dart';
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
  unsupportedByEvidence,
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
    this.minimumEvidenceConfidence = 0.5,
  });

  static const Set<String> _rootKeys = <String>{
    'merchant',
    'documentType',
    'purchaseDate',
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
  final double minimumEvidenceConfidence;

  DraftValidationResult validate({
    required String modelOutput,
    required OcrEvidence evidence,
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
    if (decoded is! Map<String, Object?>) {
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
    _validateKeys(decoded, _rootKeys, r'$', issues);

    final merchant = _nullableString(
      decoded['merchant'],
      r'$.merchant',
      issues,
    );
    final documentType = _nullableString(
      decoded['documentType'],
      r'$.documentType',
      issues,
    );
    final purchaseDateValue = decoded['purchaseDate'];
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

    final currencyValue = _nullableString(
      decoded['currency'],
      r'$.currency',
      issues,
      maxLength: 32,
    );
    final currencyCode = CurrencyNormalizer.normalize(currencyValue);
    final currency = currencyCode ?? currencyValue;

    final totalValue = decoded['total'];
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
    final productsValue = decoded['products'];
    if (productsValue is! List<Object?>) {
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
        if (item is! Map<String, Object?>) {
          issues.add(
            DraftValidationIssue(
              code: DraftValidationCode.invalidType,
              path: path,
              message: 'Each product must be a JSON object.',
            ),
          );
          continue;
        }
        _validateKeys(item, _productKeys, path, issues);
        final name = _nullableString(item['name'], '$path.name', issues);
        final quantity = _nullableQuantity(
          item['quantity'],
          '$path.quantity',
          issues,
        );
        final unitPriceMinor = _nullableMoney(
          item['unitPrice'],
          '$path.unitPrice',
          currencyCode,
          issues,
        );
        final lineTotalMinor = _nullableMoney(
          item['lineTotal'],
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
                message: 'quantity × unitPrice does not equal lineTotal.',
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

    final warrantyValue = decoded['warrantyMonths'];
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
    _nullableString(decoded['rawText'], r'$.rawText', issues, maxLength: 20000);

    if (issues.isEmpty) {
      _crossCheckEvidence(
        evidence: evidence,
        merchant: merchant,
        documentType: documentType,
        purchaseDate: purchaseDate,
        totalMinor: totalMinor,
        currency: currency,
        currencyCode: currencyCode,
        products: products,
        warrantyMonths: warrantyMonths,
        issues: issues,
      );
    }
    if (issues.isNotEmpty) {
      return DraftValidationResult(issues: List.unmodifiable(issues));
    }
    return DraftValidationResult(
      issues: const <DraftValidationIssue>[],
      draft: InvoiceDraft(
        merchant: merchant,
        documentType: documentType,
        purchaseDate: purchaseDate,
        totalMinor: totalMinor,
        currency: currency,
        products: products,
        warrantyMonths: warrantyMonths,
        rawText: evidence.rawText,
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

  void _crossCheckEvidence({
    required OcrEvidence evidence,
    required String? merchant,
    required String? documentType,
    required DateTime? purchaseDate,
    required int? totalMinor,
    required String? currency,
    required String? currencyCode,
    required List<InvoiceItemDraft> products,
    required int? warrantyMonths,
    required List<DraftValidationIssue> issues,
  }) {
    final trustedLines = evidence.lines
        .where((line) => line.confidence >= minimumEvidenceConfidence)
        .toList(growable: false);
    final trustedEvidence = trustedLines.map((line) => line.text).join('\n');
    final normalizedEvidence = InvoiceTextNormalizer.normalizeForEvidenceMatch(
      trustedEvidence,
    );
    void requireTextEvidence(String? value, String path) {
      if (value == null) return;
      final normalized = InvoiceTextNormalizer.normalizeForEvidenceMatch(value);
      final meaningfulTokens = normalized
          .split(' ')
          .where((token) => token.length > 1)
          .toList(growable: false);
      if (meaningfulTokens.isNotEmpty &&
          meaningfulTokens.any(
            (token) => !normalizedEvidence.contains(token),
          )) {
        issues.add(
          DraftValidationIssue(
            code: DraftValidationCode.unsupportedByEvidence,
            path: path,
            message: 'The value is not supported by the supplied OCR evidence.',
          ),
        );
      }
    }

    requireTextEvidence(merchant, r'$.merchant');
    requireTextEvidence(documentType, r'$.documentType');
    for (var index = 0; index < products.length; index++) {
      final product = products[index];
      final path = '\$.products[$index]';
      requireTextEvidence(product.name, '$path.name');
      final productEvidence = _productEvidenceText(product.name, trustedLines);
      final productMoneyEvidence = MoneyNormalizer.extractMinorAmounts(
        productEvidence,
        currencyCode: currencyCode,
      );
      final productQuantityEvidence = MoneyNormalizer.extractScaledNumbers(
        productEvidence,
        fractionDigits: 6,
      );
      if (product.quantity != null) {
        final scaled = MoneyNormalizer.decimalStringToMinor(
          product.quantity!.toString(),
          fractionDigits: 6,
        );
        if (scaled == null || !productQuantityEvidence.contains(scaled)) {
          issues.add(
            DraftValidationIssue(
              code: DraftValidationCode.unsupportedByEvidence,
              path: '$path.quantity',
              message: 'The quantity is absent from trusted OCR evidence.',
            ),
          );
        }
      }
      _requireMoneyEvidence(
        product.unitPriceMinor,
        '$path.unitPrice',
        productMoneyEvidence,
        issues,
      );
      _requireMoneyEvidence(
        product.lineTotalMinor,
        '$path.lineTotal',
        productMoneyEvidence,
        issues,
      );
    }
    if (purchaseDate != null) {
      final candidates = InvoiceDateNormalizer.extractDates(trustedEvidence);
      final supported = candidates.any(
        (candidate) =>
            candidate.year == purchaseDate.year &&
            candidate.month == purchaseDate.month &&
            candidate.day == purchaseDate.day,
      );
      if (!supported) {
        issues.add(
          const DraftValidationIssue(
            code: DraftValidationCode.unsupportedByEvidence,
            path: r'$.purchaseDate',
            message: 'The date does not occur in the supplied OCR evidence.',
          ),
        );
      }
    }
    if (totalMinor != null) {
      final totalEvidence = trustedLines
          .where((line) => _looksLikeTotalLine(line.text))
          .map((line) => line.text)
          .join('\n');
      final totalAmounts = MoneyNormalizer.extractMinorAmounts(
        totalEvidence,
        currencyCode: currencyCode,
      );
      if (!totalAmounts.contains(totalMinor)) {
        issues.add(
          const DraftValidationIssue(
            code: DraftValidationCode.unsupportedByEvidence,
            path: r'$.total',
            message: 'The total does not occur in the supplied OCR evidence.',
          ),
        );
      }
    }
    if (currencyCode != null) {
      final supported = CurrencyNormalizer.isSupportedByEvidence(
        currencyCode,
        trustedEvidence,
      );
      if (!supported) {
        issues.add(
          const DraftValidationIssue(
            code: DraftValidationCode.unsupportedByEvidence,
            path: r'$.currency',
            message:
                'The currency does not occur in the supplied OCR evidence.',
          ),
        );
      }
    } else {
      requireTextEvidence(currency, r'$.currency');
    }
    final warrantyEvidence = trustedLines
        .where((line) => _looksLikeWarrantyLine(line.text))
        .map((line) => line.text)
        .join('\n');
    final warrantyNumbers = MoneyNormalizer.extractScaledNumbers(
      warrantyEvidence,
      fractionDigits: 0,
    );
    if (warrantyMonths != null && !warrantyNumbers.contains(warrantyMonths)) {
      issues.add(
        const DraftValidationIssue(
          code: DraftValidationCode.unsupportedByEvidence,
          path: r'$.warrantyMonths',
          message: 'Warranty months are absent from trusted OCR evidence.',
        ),
      );
    }
    final lineTotals = products
        .map((product) => product.lineTotalMinor)
        .whereType<int>();
    if (totalMinor != null &&
        lineTotals.length == products.length &&
        products.isNotEmpty) {
      final sum = lineTotals.fold<int>(0, (total, value) => total + value);
      if (sum > totalMinor) {
        issues.add(
          const DraftValidationIssue(
            code: DraftValidationCode.inconsistentArithmetic,
            path: r'$.products',
            message:
                'The sum of line totals is greater than the invoice total.',
          ),
        );
      }
    }
  }

  void _requireMoneyEvidence(
    int? value,
    String path,
    Set<int> evidence,
    List<DraftValidationIssue> issues,
  ) {
    if (value == null || evidence.contains(value)) return;
    issues.add(
      DraftValidationIssue(
        code: DraftValidationCode.unsupportedByEvidence,
        path: path,
        message: 'The amount is absent from trusted OCR evidence.',
      ),
    );
  }

  bool _looksLikeTotalLine(String source) {
    final normalized = InvoiceTextNormalizer.normalizeForEvidenceMatch(source);
    final tokens = normalized.split(' ').toSet();
    return tokens.contains('الاجمالي') ||
        tokens.contains('المجموع') ||
        normalized.contains('المبلغ المستحق') ||
        tokens.contains('total') ||
        normalized.contains('amount due') ||
        normalized.contains('grand total') ||
        normalized.contains('net total');
  }

  bool _looksLikeWarrantyLine(String source) {
    final normalized = InvoiceTextNormalizer.normalizeForEvidenceMatch(source);
    final tokens = normalized.split(' ').toSet();
    return tokens.contains('ضمان') ||
        tokens.contains('الضمان') ||
        tokens.contains('كفاله') ||
        tokens.contains('warranty') ||
        normalized.contains('guarantee period');
  }

  String _productEvidenceText(String? name, List<OcrLine> lines) {
    if (name == null) return '';
    final normalizedName = InvoiceTextNormalizer.normalizeForEvidenceMatch(
      name,
    );
    final tokens = normalizedName
        .split(' ')
        .where((token) => token.isNotEmpty)
        .toList(growable: false);
    if (tokens.isEmpty) return '';
    final selected = <int>{};
    for (var index = 0; index < lines.length; index++) {
      final line = InvoiceTextNormalizer.normalizeForEvidenceMatch(
        lines[index].text,
      );
      if (tokens.every(line.contains)) {
        selected.add(index);
        if (index + 1 < lines.length) selected.add(index + 1);
      }
    }
    final ordered = selected.toList()..sort();
    return ordered.map((index) => lines[index].text).join('\n');
  }
}
