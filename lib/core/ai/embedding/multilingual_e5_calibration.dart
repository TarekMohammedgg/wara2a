import '../../../features/search/repositories/search_repository.dart';
import 'multilingual_e5_artifact.dart';

/// Immutable binding between semantic search release calibration and the
/// pinned offline multilingual-E5 deployment contract.
///
/// Production stays [blocked] until Android arm64 evidence approves a
/// threshold against an ar/en/mixed labeled set with honest no-result cases.
abstract final class MultilingualE5Calibration {
  static const primaryCorpusVersion = 'phase7-phase10-corpus-v1';
  static const englishCohortVersion = 'semantic-search-calibration-en-v1';
  static const hostEvidenceDoc =
      'docs/evaluation/phase8-multilingual-embedding-host-benchmark.md';

  /// Exact model/runtime/schema identity that any approved threshold must cite.
  static const modelId = MultilingualE5Artifact.modelId;
  static const modelSha256 = MultilingualE5Artifact.modelSha256;
  static const dimensions = MultilingualE5Artifact.dimensions;
  static const embeddingSchemaVersion =
      MultilingualE5Artifact.embeddingSchemaVersion;
  static const promptContract = MultilingualE5Artifact.promptContract;
  static const requiredLanguages = <String>['ar', 'en', 'mixed'];

  /// Production gate. Do not approve from host-only evidence.
  static const SemanticSearchCalibration production =
      SemanticSearchCalibration.blocked();

  /// Builds an approved calibration only when the caller supplies a complete
  /// evidence binding that matches the pinned E5 artifact contract.
  static SemanticSearchCalibration approved({
    required double maximumCosineDistance,
    required String approvedCorpusVersion,
    required int labeledQueryCount,
    required int noResultQueryCount,
    required List<String> languages,
  }) {
    final calibration = SemanticSearchCalibration.approved(
      maximumCosineDistance: maximumCosineDistance,
      approvedCorpusVersion: approvedCorpusVersion,
      labeledQueryCount: labeledQueryCount,
      noResultQueryCount: noResultQueryCount,
      languages: languages,
      modelId: modelId,
      modelSha256: modelSha256,
      dimensions: dimensions,
      embeddingSchemaVersion: embeddingSchemaVersion,
      promptContract: promptContract,
    );
    if (!calibration.canReturnSemanticResults) {
      throw StateError(
        'E5 calibration evidence is incomplete or unbound to the pinned model.',
      );
    }
    if (calibration.modelId != modelId ||
        calibration.modelSha256 != modelSha256 ||
        calibration.dimensions != dimensions ||
        calibration.embeddingSchemaVersion != embeddingSchemaVersion ||
        calibration.promptContract != promptContract) {
      throw StateError('E5 calibration drifted from the pinned artifact.');
    }
    return calibration;
  }
}
