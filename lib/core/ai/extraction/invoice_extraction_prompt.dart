import 'dart:convert';

import '../ocr/ocr_evidence.dart';
import 'invoice_draft_validator.dart';
import 'invoice_text_normalizer.dart';

enum InterpretationAttempt { initial, repair }

class InvoiceExtractionPromptBuilder {
  const InvoiceExtractionPromptBuilder({
    this.maximumLines = 200,
    this.maximumEvidenceCharacters = 12000,
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
        : '\nThe previous response was rejected. Correct only these schema/evidence errors:\n'
              '${jsonEncode(validationIssues.map((issue) => issue.toPromptJson()).toList())}\n';
    return '''
You extract an invoice draft from OCR evidence only. You never see the image.
Read only the supplied lines, their order, boxes, scripts, and confidence.
Preserve Arabic and English names as printed. Low-confidence or conflicting evidence is uncertain.
Use null when a value is absent, obscured, or uncertain. Do not use general knowledge.
Do not calculate missing facts from assumptions.
$repairSection
Return exactly one JSON object with every key below, no markdown and no commentary:
{
  "merchant": string|null,
  "documentType": string|null,
  "purchaseDate": "YYYY-MM-DD"|null,
  "total": number|null,
  "currency": string|null,
  "products": [
    {"name": string|null, "quantity": number|null, "unitPrice": number|null, "lineTotal": number|null}
  ],
  "warrantyMonths": integer|null,
  "rawText": string|null
}

OCR evidence (coordinates are source-image pixels):
$serializedEvidence
'''
        .trim();
  }

  String _serializeEvidence(OcrEvidence evidence) {
    final serialized = <Map<String, Object?>>[];
    var characterCount = 0;
    for (final line in evidence.lines.take(maximumLines)) {
      final normalized = InvoiceTextNormalizer.normalizeEvidenceText(line.text);
      if (characterCount + normalized.length > maximumEvidenceCharacters) break;
      characterCount += normalized.length;
      serialized.add(<String, Object?>{
        'order': line.order,
        'text': line.text,
        'normalizedText': normalized,
        'box': line.box.points
            .map((point) => <num>[point.x.round(), point.y.round()])
            .toList(growable: false),
        'script': line.script.name,
        'confidence': double.parse(line.confidence.toStringAsFixed(4)),
        'recognizer': line.recognizer,
      });
    }
    return jsonEncode(<String, Object?>{
      'image': <String, int>{
        'width': evidence.imageWidth,
        'height': evidence.imageHeight,
      },
      'lines': serialized,
      'truncated': serialized.length < evidence.lines.length,
    });
  }
}
