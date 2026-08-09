import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:wara2a/core/ai/embedding/embedding_engine.dart';
import 'package:wara2a/core/ai/embedding/embedding_gemma_artifact.dart';
import 'package:wara2a/core/ai/embedding/reviewed_invoice_indexer.dart';
import 'package:wara2a/core/ai/model_management/model_lifecycle_state.dart';

import '../fixture_loader.dart';
import 'contract_evaluation_harness.dart';

void main() {
  test('fixture is multilingual and explicitly contract-only', () async {
    final fixture = EmbeddingContractEvaluationFixture.parse(
      await loadFixture('search/embedding_contract_evaluation.json'),
    );

    expect(fixture.schemaVersion, 1);
    expect(fixture.evidenceClass, 'contract_only');
    expect(fixture.productionSemanticQualityClaim, isFalse);
    expect(
      fixture.cases.map((evaluationCase) => evaluationCase.language),
      containsAll(<String>['ar', 'en', 'ar-en']),
    );
  });

  test(
    'harness verifies engine/indexer contracts without a quality claim',
    () async {
      final fixture = EmbeddingContractEvaluationFixture.parse(
        await loadFixture('search/embedding_contract_evaluation.json'),
      );
      final engine = _FixtureEmbeddingEngine();
      final indexer = _RecordingReviewedInvoiceIndexer();
      final rankings = <String, List<int>>{
        'ضمان شاشة سامسونج': <int>[101, 102, 103],
        'office chair receipt': <int>[102, 101, 103],
        'Carrefour سماعة AirPods': <int>[999, 998, 997],
      };
      final harness = EmbeddingContractEvaluationHarness(
        engine: engine,
        indexer: indexer,
        retrieve: (query, {required topK}) async => rankings[query]!,
      );

      final report = await harness.run(fixture);

      expect(indexer.invoiceIds, <int>[101, 102, 103]);
      expect(engine.queries, fixture.cases.map((entry) => entry.query));
      expect(report.evaluatedCases, 3);
      expect(report.hitsAtK, 2);
      expect(report.fixtureHitRate, closeTo(2 / 3, 1e-12));
      expect(report.productionSemanticQualityEvidence, isFalse);
    },
  );

  test('parser refuses a production semantic quality claim', () async {
    final source = await loadFixture(
      'search/embedding_contract_evaluation.json',
    );

    expect(
      () => EmbeddingContractEvaluationFixture.parse(
        source.replaceFirst(
          '"productionSemanticQualityClaim": false',
          '"productionSemanticQualityClaim": true',
        ),
      ),
      throwsFormatException,
    );
  });
}

class _FixtureEmbeddingEngine implements EmbeddingEngine {
  final List<String> queries = <String>[];
  final StreamController<EmbeddingEngineSnapshot> _controller =
      StreamController<EmbeddingEngineSnapshot>.broadcast();

  @override
  EmbeddingEngineSnapshot get snapshot => const EmbeddingEngineSnapshot(
    status: ModelLifecycleStatus.ready,
    capability: EmbeddingCapability.ready,
    modelId: EmbeddingGemmaArtifact.modelId,
  );

  @override
  Stream<EmbeddingEngineSnapshot> get snapshots => _controller.stream;

  @override
  Future<void> cancel() async {}

  @override
  Future<void> dispose() => _controller.close();

  @override
  Future<EmbeddingOutput> embedDocument(String searchableText) =>
      _output(searchableText);

  @override
  Future<EmbeddingOutput> embedQuery(String normalizedQuery) {
    queries.add(normalizedQuery);
    return _output(normalizedQuery);
  }

  Future<EmbeddingOutput> _output(String _) async {
    final vector = List<double>.filled(EmbeddingGemmaArtifact.dimensions, 0)
      ..[0] = 1;
    return EmbeddingOutput(
      vector: List<double>.unmodifiable(vector),
      modelId: EmbeddingGemmaArtifact.modelId,
      dimensions: EmbeddingGemmaArtifact.dimensions,
      schemaVersion: EmbeddingGemmaArtifact.embeddingSchemaVersion,
    );
  }

  @override
  Future<void> install() async {}

  @override
  Future<EmbeddingEngineSnapshot> refresh() async => snapshot;

  @override
  Future<void> unload() async {}
}

class _RecordingReviewedInvoiceIndexer implements ReviewedInvoiceIndexer {
  final List<int> invoiceIds = <int>[];

  @override
  Future<void> indexReviewedInvoice(int invoiceId) async {
    invoiceIds.add(invoiceId);
  }
}
