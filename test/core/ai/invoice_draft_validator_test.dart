import 'package:flutter_test/flutter_test.dart';
import 'package:wara2a/core/ai/extraction/invoice_draft_validator.dart';
import 'package:wara2a/features/invoice_capture/models/invoice_draft.dart';

import 'fixture_loader.dart';

void main() {
  test('accepts a strict evidence-backed Arabic and Latin invoice', () async {
    final evidence = await loadOcrEvidenceFixture(
      'ocr/mixed_arabic_invoice.json',
    );
    final output = await loadFixture('extraction/valid_invoice.json');

    final result = const InvoiceDraftValidator().validate(
      modelOutput: output,
      evidence: evidence,
      origin: InvoiceDraftOrigin.extracted,
    );

    expect(result.issues, isEmpty);
    expect(result.draft, isNotNull);
    expect(result.draft!.merchant, 'بي تك');
    expect(result.draft!.purchaseDate, DateTime.utc(2026, 8, 9));
    expect(result.draft!.totalMinor, 2499900);
    expect(result.draft!.currencyCode, 'EGP');
    expect(result.draft!.products.single.lineTotalMinor, 2499900);
    expect(result.draft!.rawText, contains('الإجمالي'));
    expect(result.draft!.requiresManualReview, isTrue);
    expect(result.draft!.copyWith(merchant: null).merchant, isNull);
  });

  test(
    'rejects markdown, unknown keys, and unsupported hallucinations',
    () async {
      final evidence = await loadOcrEvidenceFixture(
        'ocr/mixed_arabic_invoice.json',
      );
      const validator = InvoiceDraftValidator();

      final markdown = validator.validate(
        modelOutput: '```json\n{}\n```',
        evidence: evidence,
        origin: InvoiceDraftOrigin.extracted,
      );
      expect(markdown.issues.single.code, DraftValidationCode.invalidJson);

      final unknownKey = validator.validate(
        modelOutput:
            '{"merchant":null,"documentType":null,"purchaseDate":null,'
            '"total":null,"currency":null,"products":[],'
            '"warrantyMonths":null,"rawText":null,"invoiceNumber":"x"}',
        evidence: evidence,
        origin: InvoiceDraftOrigin.extracted,
      );
      expect(
        unknownKey.issues.map((issue) => issue.code),
        contains(DraftValidationCode.unknownKey),
      );

      final hallucination = validator.validate(
        modelOutput:
            '{"merchant":"متجر غير موجود","documentType":null,'
            '"purchaseDate":null,"total":null,"currency":null,'
            '"products":[],"warrantyMonths":null,"rawText":null}',
        evidence: evidence,
        origin: InvoiceDraftOrigin.extracted,
      );
      expect(
        hallucination.issues.map((issue) => issue.code),
        contains(DraftValidationCode.unsupportedByEvidence),
      );

      final unrelatedNumberAsTotal = validator.validate(
        modelOutput:
            '{"merchant":null,"documentType":null,"purchaseDate":null,'
            '"total":12,"currency":"EGP","products":[],'
            '"warrantyMonths":null,"rawText":null}',
        evidence: evidence,
        origin: InvoiceDraftOrigin.extracted,
      );
      expect(
        unrelatedNumberAsTotal.issues
            .where((issue) => issue.path == r'$.total')
            .map((issue) => issue.code),
        contains(DraftValidationCode.unsupportedByEvidence),
      );

      final unknownCurrency = validator.validate(
        modelOutput:
            '{"merchant":null,"documentType":null,"purchaseDate":null,'
            '"total":24999,"currency":"XYZ","products":[],'
            '"warrantyMonths":null,"rawText":null}',
        evidence: evidence,
        origin: InvoiceDraftOrigin.extracted,
      );
      expect(
        unknownCurrency.issues.map((issue) => issue.code),
        contains(DraftValidationCode.invalidCurrency),
      );
    },
  );
}
