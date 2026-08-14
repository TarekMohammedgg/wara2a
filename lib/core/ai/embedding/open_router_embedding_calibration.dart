import '../../../features/search/repositories/search_repository.dart';
import 'open_router_embedding_artifact.dart';

/// Calibration binding for OpenRouter text-embedding-3-small retrieval.
abstract final class OpenRouterEmbeddingCalibration {
  static final SemanticSearchCalibration production =
      SemanticSearchCalibration.approved(
        maximumCosineDistance: 0.55,
        approvedCorpusVersion: 'openrouter-text-embedding-3-small-v1',
        labeledQueryCount: 100,
        noResultQueryCount: 20,
        languages: const <String>['ar', 'en', 'mixed'],
        modelId: OpenRouterEmbeddingArtifact.modelId,
        modelSha256: OpenRouterEmbeddingArtifact.contractSha256,
        dimensions: OpenRouterEmbeddingArtifact.dimensions,
        embeddingSchemaVersion:
            OpenRouterEmbeddingArtifact.embeddingSchemaVersion,
        promptContract: OpenRouterEmbeddingArtifact.promptContract,
      );
}
