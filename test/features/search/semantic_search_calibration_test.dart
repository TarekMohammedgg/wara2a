import 'package:flutter_test/flutter_test.dart';
import 'package:wara2a/core/ai/embedding/embedding_engine.dart';
import 'package:wara2a/core/ai/embedding/multilingual_e5_artifact.dart';
import 'package:wara2a/core/ai/embedding/multilingual_e5_calibration.dart';
import 'package:wara2a/features/search/repositories/search_repository.dart';

void main() {
  final calibration = MultilingualE5Calibration.approved(
    maximumCosineDistance: 0.16,
    approvedCorpusVersion: MultilingualE5Calibration.primaryCorpusVersion,
    labeledQueryCount: 130,
    noResultQueryCount: 30,
    languages: MultilingualE5Calibration.requiredLanguages,
  );

  test('approved calibration is bound to language, negatives, and model', () {
    expect(calibration.canReturnSemanticResults, isTrue);
    expect(calibration.modelId, MultilingualE5Artifact.modelId);
    expect(calibration.modelSha256, MultilingualE5Artifact.modelSha256);
    expect(calibration.dimensions, MultilingualE5Artifact.dimensions);
    expect(
      calibration.embeddingSchemaVersion,
      MultilingualE5Artifact.embeddingSchemaVersion,
    );
    expect(calibration.promptContract, MultilingualE5Artifact.promptContract);
    expect(
      calibration.accepts(
        const EmbeddingOutput(
          vector: <double>[],
          modelId: MultilingualE5Artifact.modelId,
          dimensions: MultilingualE5Artifact.dimensions,
          schemaVersion: MultilingualE5Artifact.embeddingSchemaVersion,
        ),
      ),
      isTrue,
    );
    expect(
      calibration.accepts(
        const EmbeddingOutput(
          vector: <double>[],
          modelId: 'different-model',
          dimensions: MultilingualE5Artifact.dimensions,
          schemaVersion: MultilingualE5Artifact.embeddingSchemaVersion,
        ),
      ),
      isFalse,
    );
  });

  test('production calibration remains blocked until Android evidence', () {
    expect(
      MultilingualE5Calibration.production.canReturnSemanticResults,
      isFalse,
    );
    const blocked = SemanticSearchCalibration.blocked();
    expect(blocked.canReturnSemanticResults, isFalse);
  });
}
