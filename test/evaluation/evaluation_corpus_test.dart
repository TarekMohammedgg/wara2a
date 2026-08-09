import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'evaluation_corpus.dart';

EvaluationCorpus _loadCorpus() {
  return EvaluationCorpus.fromJsonLines(
    invoicesJsonl: File(
      'test/fixtures/evaluation/invoices.jsonl',
    ).readAsStringSync(),
    queriesJsonl: File(
      'test/fixtures/evaluation/search_queries.jsonl',
    ).readAsStringSync(),
  );
}

void main() {
  late EvaluationCorpus corpus;

  setUpAll(() {
    corpus = _loadCorpus();
  });

  test('contains the Phase 7 and Phase 9-10 corpus minimums', () {
    expect(corpus.invoices, hasLength(50));
    expect(corpus.queries, hasLength(100));
    expect(EvaluationCorpusValidator.validate(corpus), isEmpty);
  });

  test('invoice and query identifiers are unique and references resolve', () {
    final invoiceIds = corpus.invoices
        .map((invoice) => invoice.caseId)
        .toList();
    final queryIds = corpus.queries.map((query) => query.queryId).toList();
    expect(invoiceIds.toSet(), hasLength(invoiceIds.length));
    expect(queryIds.toSet(), hasLength(queryIds.length));
    expect(
      corpus.queries.expand((query) => query.expectedInvoiceIds),
      everyElement(isIn(invoiceIds)),
    );
  });

  test('covers extraction, layout, image-quality, and route categories', () {
    expect(
      corpus.invoices.map((invoice) => invoice.language).toSet(),
      containsAll({'ar', 'en', 'mixed'}),
    );
    expect(
      corpus.invoices.map((invoice) => invoice.layout).toSet(),
      containsAll({'thermal', 'a4'}),
    );
    expect(
      corpus.invoices.map((invoice) => invoice.digitScript).toSet(),
      containsAll({'latin', 'arabic-indic', 'persian'}),
    );
    expect(
      corpus.invoices.map((invoice) => invoice.glare).toSet(),
      containsAll({'none', 'mild', 'strong'}),
    );
    expect(
      corpus.invoices.map((invoice) => invoice.contrast).toSet(),
      containsAll({'normal', 'low'}),
    );
    expect(
      corpus.invoices.map((invoice) => invoice.conditions['occlusion']).toSet(),
      containsAll({'none', 'partial'}),
    );
    expect(
      corpus.invoices.any((invoice) => invoice.obscuredFields.isNotEmpty),
      isTrue,
    );
    expect(
      corpus.invoices.any((invoice) => invoice.nullFields.isNotEmpty),
      isTrue,
    );
    expect(
      corpus.queries.map((query) => query.expectedRoute).toSet(),
      containsAll({'keyword', 'structured', 'semantic', 'hybrid'}),
    );
  });

  test('retrieval metrics use Recall@K, MRR, and top-five false positives', () {
    final queries = <SearchQueryEvaluationCase>[
      SearchQueryEvaluationCase(
        corpusVersion: evaluationCorpusVersion,
        queryId: 'q1',
        text: 'x',
        language: 'ar',
        expectedRoute: 'semantic',
        expectedInvoiceIds: ['invoice-001'],
        filters: const {},
      ),
      SearchQueryEvaluationCase(
        corpusVersion: evaluationCorpusVersion,
        queryId: 'q2',
        text: 'x',
        language: 'mixed',
        expectedRoute: 'keyword',
        expectedInvoiceIds: ['invoice-002'],
        filters: const {},
      ),
      SearchQueryEvaluationCase(
        corpusVersion: evaluationCorpusVersion,
        queryId: 'q3',
        text: 'x',
        language: 'ar',
        expectedRoute: 'structured',
        expectedInvoiceIds: ['invoice-003'],
        filters: const {'currencyCode': 'EGP'},
      ),
    ];
    final metrics = RetrievalMetrics.fromResults(
      queries: queries,
      resultsByQueryId: {
        'q1': ['invoice-001'],
        'q2': ['invoice-099', 'invoice-002'],
        'q3': ['invoice-098'],
      },
    );
    expect(metrics.recallAt1, closeTo(1 / 3, 0.000001));
    expect(metrics.recallAt5, closeTo(2 / 3, 0.000001));
    expect(metrics.meanReciprocalRank, closeTo(0.5, 0.000001));
    expect(metrics.falsePositiveRateAt5, closeTo(2 / 4, 0.000001));
  });

  test(
    'extraction metrics treat nulls as exact and normalize merchant text',
    () {
      expect(ExtractionMetrics.fieldExactMatch(null, null), isTrue);
      expect(
        ExtractionMetrics.fieldExactMatch(' Cairo  Byte ', 'cairo byte'),
        isTrue,
      );
      expect(ExtractionMetrics.fieldExactMatch('EGP', 'USD'), isFalse);
      expect(
        ExtractionMetrics.fieldAccuracy(
          expected: {'merchant': 'Cairo Byte', 'currency': 'EGP'},
          actual: {'merchant': 'cairo byte', 'currency': 'EGP'},
          fields: const ['merchant', 'currency'],
        ),
        1,
      );
      expect(
        ExtractionMetrics.productItemF1(
          expected: const [
            {'name': 'Nova Phone'},
            {'name': 'Wave Headset'},
          ],
          actual: const [
            {'name': 'nova phone'},
            {'name': 'Wrong Item'},
          ],
        ),
        closeTo(0.5, 0.000001),
      );
    },
  );
}
