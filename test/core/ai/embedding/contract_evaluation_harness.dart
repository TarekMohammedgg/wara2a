import 'dart:convert';

import 'package:wara2a/core/ai/embedding/embedding_engine.dart';
import 'package:wara2a/core/ai/embedding/embedding_vector_validator.dart';
import 'package:wara2a/core/ai/embedding/multilingual_e5_artifact.dart';
import 'package:wara2a/core/ai/embedding/reviewed_invoice_indexer.dart';

typedef ContractRetriever =
    Future<List<int>> Function(String query, {required int topK});

class EmbeddingContractEvaluationFixture {
  const EmbeddingContractEvaluationFixture({
    required this.schemaVersion,
    required this.evidenceClass,
    required this.purpose,
    required this.productionSemanticQualityClaim,
    required this.modelId,
    required this.dimensions,
    required this.embeddingSchemaVersion,
    required this.corpusInvoiceIds,
    required this.cases,
  });

  final int schemaVersion;
  final String evidenceClass;
  final String purpose;
  final bool productionSemanticQualityClaim;
  final String modelId;
  final int dimensions;
  final int embeddingSchemaVersion;
  final List<int> corpusInvoiceIds;
  final List<EmbeddingContractEvaluationCase> cases;

  factory EmbeddingContractEvaluationFixture.parse(String source) {
    final root = jsonDecode(source) as Map<String, dynamic>;
    final model = root['modelContract'] as Map<String, dynamic>;
    final fixture = EmbeddingContractEvaluationFixture(
      schemaVersion: root['schemaVersion'] as int,
      evidenceClass: root['evidenceClass'] as String,
      purpose: root['purpose'] as String,
      productionSemanticQualityClaim:
          root['productionSemanticQualityClaim'] as bool,
      modelId: model['modelId'] as String,
      dimensions: model['dimensions'] as int,
      embeddingSchemaVersion: model['embeddingSchemaVersion'] as int,
      corpusInvoiceIds: List<int>.unmodifiable(
        (root['corpusInvoiceIds'] as List<dynamic>).cast<int>(),
      ),
      cases: List<EmbeddingContractEvaluationCase>.unmodifiable(
        (root['cases'] as List<dynamic>).map(
          (entry) => EmbeddingContractEvaluationCase.fromJson(
            entry as Map<String, dynamic>,
          ),
        ),
      ),
    );
    fixture._validate();
    return fixture;
  }

  void _validate() {
    if (schemaVersion != 1 || evidenceClass != 'contract_only') {
      throw const FormatException(
        'Only contract-only evaluation fixture schema 1 is supported.',
      );
    }
    if (productionSemanticQualityClaim) {
      throw const FormatException(
        'Contract fixtures cannot claim production semantic quality.',
      );
    }
    if (modelId != MultilingualE5Artifact.modelId ||
        dimensions != MultilingualE5Artifact.dimensions ||
        embeddingSchemaVersion !=
            MultilingualE5Artifact.embeddingSchemaVersion) {
      throw const FormatException(
        'Evaluation fixture does not match the pinned embedding contract.',
      );
    }
    if (corpusInvoiceIds.isEmpty || cases.isEmpty) {
      throw const FormatException(
        'Evaluation fixture requires a corpus and at least one case.',
      );
    }
    for (final evaluationCase in cases) {
      evaluationCase._validate(corpusInvoiceIds);
    }
  }
}

class EmbeddingContractEvaluationCase {
  const EmbeddingContractEvaluationCase({
    required this.id,
    required this.language,
    required this.query,
    required this.topK,
    required this.relevantInvoiceIds,
  });

  final String id;
  final String language;
  final String query;
  final int topK;
  final List<int> relevantInvoiceIds;

  factory EmbeddingContractEvaluationCase.fromJson(Map<String, dynamic> json) =>
      EmbeddingContractEvaluationCase(
        id: json['id'] as String,
        language: json['language'] as String,
        query: json['query'] as String,
        topK: json['topK'] as int,
        relevantInvoiceIds: List<int>.unmodifiable(
          (json['relevantInvoiceIds'] as List<dynamic>).cast<int>(),
        ),
      );

  void _validate(List<int> corpusInvoiceIds) {
    if (id.trim().isEmpty || query.trim().isEmpty || topK <= 0) {
      throw FormatException('Invalid contract evaluation case: $id.');
    }
    if (relevantInvoiceIds.isEmpty ||
        relevantInvoiceIds.any((id) => !corpusInvoiceIds.contains(id))) {
      throw FormatException(
        'Relevant invoice IDs for $id must belong to the fixture corpus.',
      );
    }
  }
}

class EmbeddingContractEvaluationHarness {
  const EmbeddingContractEvaluationHarness({
    required this.engine,
    required this.indexer,
    required this.retrieve,
  });

  final EmbeddingEngine engine;
  final ReviewedInvoiceIndexer indexer;
  final ContractRetriever retrieve;

  Future<EmbeddingContractEvaluationReport> run(
    EmbeddingContractEvaluationFixture fixture,
  ) async {
    final snapshot = await engine.refresh();
    if (!snapshot.canEmbed) {
      throw EmbeddingUnavailableException(
        snapshot.message ??
            'Embedding engine is not ready for contract evaluation.',
      );
    }
    if (snapshot.modelId != fixture.modelId) {
      throw StateError('Embedding engine model does not match the fixture.');
    }

    for (final invoiceId in fixture.corpusInvoiceIds) {
      await indexer.indexReviewedInvoice(invoiceId);
    }

    var hits = 0;
    for (final evaluationCase in fixture.cases) {
      final output = await engine.embedQuery(evaluationCase.query);
      _validateOutput(output, fixture);
      final ids = await retrieve(
        evaluationCase.query,
        topK: evaluationCase.topK,
      );
      final topKIds = ids.take(evaluationCase.topK).toSet();
      if (evaluationCase.relevantInvoiceIds.any(topKIds.contains)) hits++;
    }

    return EmbeddingContractEvaluationReport(
      evaluatedCases: fixture.cases.length,
      hitsAtK: hits,
    );
  }

  void _validateOutput(
    EmbeddingOutput output,
    EmbeddingContractEvaluationFixture fixture,
  ) {
    if (output.modelId != fixture.modelId ||
        output.dimensions != fixture.dimensions ||
        output.schemaVersion != fixture.embeddingSchemaVersion) {
      throw StateError('Embedding output does not match the fixture contract.');
    }
    EmbeddingVectorValidator.validateNormalized(
      output.vector,
      dimensions: fixture.dimensions,
    );
  }
}

class EmbeddingContractEvaluationReport {
  const EmbeddingContractEvaluationReport({
    required this.evaluatedCases,
    required this.hitsAtK,
  });

  final int evaluatedCases;
  final int hitsAtK;

  double get fixtureHitRate =>
      evaluatedCases == 0 ? 0 : hitsAtK / evaluatedCases;

  // A small curated contract fixture verifies wiring and repeatability only.
  // It is never release-quality evidence of semantic retrieval performance.
  bool get productionSemanticQualityEvidence => false;
}
