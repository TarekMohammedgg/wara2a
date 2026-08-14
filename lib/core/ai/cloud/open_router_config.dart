/// OpenRouter cloud settings for Gemini extraction.
class OpenRouterConfig {
  const OpenRouterConfig({
    required this.apiKey,
    this.modelId = defaultModelId,
    this.baseUrl = defaultBaseUrl,
    this.timeout = const Duration(seconds: 60),
    this.maxOutputTokens = 1024,
  });

  static const String defaultBaseUrl =
      'https://openrouter.ai/api/v1/chat/completions';

  /// Cheap multimodal Gemini suitable for invoice vision → JSON.
  static const String defaultModelId = 'google/gemini-2.5-flash-lite';

  final String apiKey;
  final String modelId;
  final String baseUrl;
  final Duration timeout;
  final int maxOutputTokens;

  Uri get baseUri => Uri.parse(baseUrl);

  /// Resolves the user-provided API key from secure settings storage.
  static String? resolveApiKey(String? settingsKey) {
    final trimmed = settingsKey?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
