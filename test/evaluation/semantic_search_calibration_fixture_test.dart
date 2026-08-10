import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'evaluation_corpus.dart';

void main() {
  test(
    'multilingual semantic calibration has honest positives and no-result cases',
    () {
      final invoiceIds = File('test/fixtures/evaluation/invoices.jsonl')
          .readAsLinesSync()
          .where((line) => line.trim().isNotEmpty)
          .map((line) => jsonDecode(line) as Map<String, dynamic>)
          .map((invoice) => invoice['caseId'] as String)
          .toSet();
      final rows = File(
        'test/fixtures/evaluation/semantic_search_calibration_queries.jsonl',
      ).readAsLinesSync().where((line) => line.trim().isNotEmpty).map((line) {
        return jsonDecode(line) as Map<String, dynamic>;
      }).toList(growable: false);

      expect(rows.map((row) => row['queryId']).toSet(), hasLength(rows.length));
      expect(rows, hasLength(78));

      final positives = rows.where((row) => row['kind'] == 'positive').toList();
      final negatives = rows
          .where((row) => row['kind'] == 'no_result')
          .toList();
      expect(positives, hasLength(30));
      expect(negatives, hasLength(48));

      for (final language in const ['ar', 'en', 'mixed']) {
        final languageRows = rows
            .where((row) => row['language'] == language)
            .toList();
        expect(languageRows, hasLength(26));
        expect(
          languageRows.where((row) => row['kind'] == 'positive'),
          hasLength(10),
        );
        expect(
          languageRows.where((row) => row['kind'] == 'no_result'),
          hasLength(16),
        );
      }

      for (final row in rows) {
        expect(row['corpusVersion'], evaluationCorpusVersion);
        expect(row['schemaVersion'], 1);
        final text = row['text'] as String;
        expect(text.trim(), isNotEmpty);
        final hasArabic = RegExp(r'[\u0600-\u06ff]').hasMatch(text);
        final hasLatin = RegExp('[a-zA-Z]').hasMatch(text);
        switch (row['language']) {
          case 'ar':
            expect(hasArabic, isTrue);
            expect(hasLatin, isFalse);
          case 'en':
            expect(hasArabic, isFalse);
            expect(hasLatin, isTrue);
            expect(text.codeUnits, everyElement(lessThan(128)));
          case 'mixed':
            expect(hasArabic, isTrue);
            expect(hasLatin, isTrue);
          default:
            fail('Unsupported calibration language: ${row['language']}');
        }
        expect((row['rationale'] as String).trim(), isNotEmpty);
      }

      for (final row in positives) {
        final expected = (row['expectedInvoiceIds'] as List<dynamic>)
            .cast<String>();
        // A family-level semantic query has no date/invoice discriminator, so
        // all five equivalent synthetic records are relevant.
        expect(expected, hasLength(5));
        expect(expected, everyElement(isIn(invoiceIds)));
      }
      for (final row in negatives) {
        expect(row['expectedInvoiceIds'], isEmpty);
      }
    },
  );
}
