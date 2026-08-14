/// Deployment contract for OpenRouter `openai/text-embedding-3-small`.
abstract final class OpenRouterEmbeddingArtifact {
  static const modelId = 'openai/text-embedding-3-small';
  static const displayName = 'OpenAI text-embedding-3-small (OpenRouter)';
  static const dimensions = 1536;
  static const embeddingSchemaVersion = 4;
  static const promptContract = 'openrouter-text-embedding-3-small-v1';
  static const maximumInputCharacters = 24000;

  /// Stable contract pin (not a downloaded file hash).
  static const contractSha256 =
      'a3f1c8e29b0476d5e4f80c1a7b9d2e6f5c4a3817092b6d8e0f1a2c3d4e5f6789';

  static const embeddingsPath = '/embeddings';
  static const defaultBaseUrl = 'https://openrouter.ai/api/v1/embeddings';
}
