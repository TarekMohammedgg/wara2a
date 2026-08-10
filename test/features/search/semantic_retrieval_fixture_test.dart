import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:wara2a/core/ai/embedding/multilingual_e5_artifact.dart';

void main() {
  test(
    'provides 100 labeled Arabic and mixed retrieval cases without claims',
    () async {
      final source = await File(
        'test/fixtures/search/semantic_retrieval_evaluation_v1.json',
      ).readAsString();
      final fixture = jsonDecode(source) as Map<String, dynamic>;
      final corpus = (fixture['corpus'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
      final cases = (fixture['cases'] as List<dynamic>)
          .cast<Map<String, dynamic>>();

      expect(fixture['schemaVersion'], 1);
      expect(fixture['evidenceClass'], 'unexecuted_labeled_fixture');
      expect(fixture['approvedForThreshold'], isFalse);
      expect(fixture['productionSemanticQualityClaim'], isFalse);
      expect(fixture['requiredModelId'], MultilingualE5Artifact.modelId);
      expect(cases, hasLength(100));
      expect(cases.map((entry) => entry['id']).toSet(), hasLength(100));

      final corpusIds = corpus.map((entry) => entry['id'] as int).toSet();
      final nonEnglish = cases.where(
        (entry) => entry['language'] == 'ar' || entry['language'] == 'ar-en',
      );
      expect(nonEnglish.length, greaterThanOrEqualTo(80));

      final coveredTags = <String>{};
      for (final evaluationCase in cases) {
        expect((evaluationCase['query'] as String).trim(), isNotEmpty);
        final relevant = (evaluationCase['relevantInvoiceIds'] as List<dynamic>)
            .cast<int>();
        expect(relevant, isNotEmpty);
        expect(relevant.every(corpusIds.contains), isTrue);
        coveredTags.addAll(
          (evaluationCase['intentTags'] as List<dynamic>).cast<String>(),
        );
      }
      expect(
        coveredTags,
        containsAll([
          'merchant',
          'product',
          'paraphrase',
          'date',
          'warranty',
          'amount',
          'currency',
        ]),
      );
    },
  );
}
