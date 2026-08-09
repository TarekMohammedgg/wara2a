import 'dart:convert';
import 'dart:io';

import 'package:wara2a/core/ai/ocr/ocr_evidence.dart';

Future<String> loadFixture(String relativePath) =>
    File('test/fixtures/$relativePath').readAsString();

Future<OcrEvidence> loadOcrEvidenceFixture(String relativePath) async {
  final decoded = jsonDecode(await loadFixture(relativePath));
  if (decoded is! Map<String, Object?>) {
    throw StateError('OCR fixture root must be an object.');
  }
  return OcrEvidence.fromMap(decoded);
}
