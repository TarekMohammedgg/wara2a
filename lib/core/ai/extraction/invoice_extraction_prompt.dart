import 'dart:convert';

import '../ocr/ocr_evidence.dart';
import 'invoice_draft_validator.dart';
import 'invoice_text_normalizer.dart';

enum InterpretationAttempt { initial, repair }

class InvoiceExtractionPromptBuilder {
  const InvoiceExtractionPromptBuilder({
    this.maximumLines = 48,
    this.maximumEvidenceCharacters = 2200,
  });

  final int maximumLines;
  final int maximumEvidenceCharacters;

  String buildInitial(OcrEvidence evidence) => _build(evidence, const []);

  String buildRepair(
    OcrEvidence evidence,
    List<DraftValidationIssue> validationIssues,
  ) => _build(evidence, validationIssues);

  String _build(
    OcrEvidence evidence,
    List<DraftValidationIssue> validationIssues,
  ) {
    final serializedEvidence = _serializeEvidence(evidence);
    final repairSection = validationIssues.isEmpty
        ? ''
        : '\nRepair these rejected fields only: '
              '${jsonEncode(validationIssues.take(12).map((issue) => issue.toPromptJson()).toList())}\n';
    return '''
Extract one invoice JSON from OCR only. Use line order, boxes, script and confidence.
Preserve printed Arabic/English names. Use null for absent, obscured, uncertain or conflicting values.
Never guess, use outside knowledge, or add commentary.$repairSection
Return exactly this object; include every key and no others:
$schema

Evidence coordinates are image pixels:
$serializedEvidence
'''
        .trim();
  }

  static const String schema =
      '{"merchant":string|null,"documentType":string|null,'
      '"purchaseDate":"YYYY-MM-DD"|null,"invoiceNumber":string|null,'
      '"total":number|null,'
      '"currency":string|null,"products":[{"name":string|null,'
      '"quantity":number|null,"unitPrice":number|null,'
      '"lineTotal":number|null}],"warrantyMonths":integer|null,'
      '"rawText":string|null}';

  String _serializeEvidence(OcrEvidence evidence) {
    final serialized = <Map<String, Object?>>[];
    for (final line in evidence.lines.take(maximumLines)) {
      final normalized = InvoiceTextNormalizer.normalizeEvidenceText(line.text);
      final xs = line.box.points.map((point) => point.x);
      final ys = line.box.points.map((point) => point.y);
      final item = <String, Object?>{
        'o': line.order,
        't': line.text,
        if (normalized != line.text) 'n': normalized,
        'b': <num>[
          xs.reduce((a, b) => a < b ? a : b).round(),
          ys.reduce((a, b) => a < b ? a : b).round(),
          xs.reduce((a, b) => a > b ? a : b).round(),
          ys.reduce((a, b) => a > b ? a : b).round(),
        ],
        's': line.script.name,
        'c': double.parse(line.confidence.toStringAsFixed(3)),
      };
      final candidate = <Map<String, Object?>>[...serialized, item];
      final candidateJson = jsonEncode(<String, Object?>{
        'w': evidence.imageWidth,
        'h': evidence.imageHeight,
        'lines': candidate,
      });
      if (candidateJson.length > maximumEvidenceCharacters) break;
      serialized.add(item);
    }
    return jsonEncode(<String, Object?>{
      'w': evidence.imageWidth,
      'h': evidence.imageHeight,
      'lines': serialized,
      'truncated': serialized.length < evidence.lines.length,
    });
  }
}
