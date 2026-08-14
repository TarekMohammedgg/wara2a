import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../ai_runtime_error.dart';
import 'open_router_config.dart';

class OpenRouterCompletionRequest {
  const OpenRouterCompletionRequest({
    required this.prompt,
    required this.imageBytes,
    required this.mimeType,
  });

  final String prompt;
  final List<int> imageBytes;
  final String mimeType;
}

class OpenRouterCompletionResult {
  const OpenRouterCompletionResult({
    required this.content,
    required this.modelId,
    required this.elapsed,
    this.promptTokens,
    this.completionTokens,
  });

  final String content;
  final String modelId;
  final Duration elapsed;
  final int? promptTokens;
  final int? completionTokens;
}

/// Minimal OpenAI-compatible OpenRouter chat client (vision + text).
class OpenRouterClient {
  OpenRouterClient({required this.config, HttpClient? httpClient})
    : _httpClient = httpClient ?? HttpClient();

  final OpenRouterConfig config;
  final HttpClient _httpClient;
  bool _disposed = false;

  Future<OpenRouterCompletionResult> complete(
    OpenRouterCompletionRequest request, {
    bool Function()? isCancelled,
  }) async {
    _ensureNotDisposed();
    final stopwatch = Stopwatch()..start();
    final dataUrl =
        'data:${request.mimeType};base64,${base64Encode(request.imageBytes)}';
    final body = <String, Object?>{
      'model': config.modelId,
      'temperature': 0,
      // Cap completion length so Gemini does not linger on long prose.
      'max_tokens': config.maxOutputTokens,
      // Prefer the lowest-latency OpenRouter provider for this model.
      'provider': <String, Object?>{'sort': 'latency'},
      'messages': <Map<String, Object?>>[
        <String, Object?>{
          'role': 'user',
          'content': <Map<String, Object?>>[
            <String, Object?>{'type': 'text', 'text': request.prompt},
            <String, Object?>{
              'type': 'image_url',
              'image_url': <String, Object?>{
                'url': dataUrl,
                // Low detail is enough for printed invoice text and is faster.
                'detail': 'low',
              },
            },
          ],
        },
      ],
    };

    late final HttpClientRequest httpRequest;
    try {
      httpRequest = await _httpClient
          .postUrl(config.baseUri)
          .timeout(config.timeout);
    } on TimeoutException catch (error) {
      throw AiRuntimeException(
        code: AiErrorCode.timeout,
        stage: 'openrouter',
        message: 'OpenRouter connection timed out.',
        cause: error,
      );
    } on Object catch (error) {
      throw AiRuntimeException(
        code: AiErrorCode.inferenceFailed,
        stage: 'openrouter',
        message: 'Could not reach OpenRouter.',
        cause: error,
      );
    }

    httpRequest.headers.set(
      HttpHeaders.authorizationHeader,
      'Bearer ${config.apiKey}',
    );
    httpRequest.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
    httpRequest.headers.set(HttpHeaders.acceptHeader, 'application/json');
    httpRequest.headers.set('HTTP-Referer', 'https://wara2a.app');
    httpRequest.headers.set('X-Title', 'wara2a-experimental');
    httpRequest.add(utf8.encode(jsonEncode(body)));

    final HttpClientResponse response;
    try {
      response = await httpRequest.close().timeout(config.timeout);
    } on TimeoutException catch (error) {
      throw AiRuntimeException(
        code: AiErrorCode.timeout,
        stage: 'openrouter',
        message: 'OpenRouter response timed out.',
        cause: error,
      );
    } on Object catch (error) {
      throw AiRuntimeException(
        code: AiErrorCode.inferenceFailed,
        stage: 'openrouter',
        message: 'OpenRouter request failed.',
        cause: error,
      );
    }
    if (isCancelled?.call() ?? false) {
      throw const AiRuntimeException(
        code: AiErrorCode.cancelled,
        stage: 'openrouter',
        message: 'The OpenRouter request was cancelled.',
      );
    }

    final payload = await response.transform(utf8.decoder).join();
    stopwatch.stop();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AiRuntimeException(
        code: AiErrorCode.inferenceFailed,
        stage: 'openrouter',
        message:
            'OpenRouter returned HTTP ${response.statusCode}: ${_shortError(payload)}',
      );
    }

    late final Object? decoded;
    try {
      decoded = jsonDecode(payload);
    } on FormatException catch (error) {
      throw AiRuntimeException(
        code: AiErrorCode.invalidRuntimeResponse,
        stage: 'openrouter',
        message: 'OpenRouter returned non-JSON.',
        cause: error,
      );
    }
    if (decoded is! Map) {
      throw const AiRuntimeException(
        code: AiErrorCode.invalidRuntimeResponse,
        stage: 'openrouter',
        message: 'OpenRouter response root must be an object.',
      );
    }
    final choices = decoded['choices'];
    if (choices is! List || choices.isEmpty || choices.first is! Map) {
      throw const AiRuntimeException(
        code: AiErrorCode.invalidRuntimeResponse,
        stage: 'openrouter',
        message: 'OpenRouter response did not include choices.',
      );
    }
    final message = (choices.first as Map)['message'];
    if (message is! Map) {
      throw const AiRuntimeException(
        code: AiErrorCode.invalidRuntimeResponse,
        stage: 'openrouter',
        message: 'OpenRouter choice message is missing.',
      );
    }
    final content = message['content'];
    if (content is! String || content.trim().isEmpty) {
      throw const AiRuntimeException(
        code: AiErrorCode.invalidModelOutput,
        stage: 'openrouter',
        message: 'OpenRouter returned an empty completion.',
      );
    }
    final usage = decoded['usage'];
    int? promptTokens;
    int? completionTokens;
    if (usage is Map) {
      final prompt = usage['prompt_tokens'];
      final completion = usage['completion_tokens'];
      if (prompt is num) promptTokens = prompt.toInt();
      if (completion is num) completionTokens = completion.toInt();
    }
    final model = decoded['model'];
    return OpenRouterCompletionResult(
      content: content,
      modelId: model is String && model.isNotEmpty ? model : config.modelId,
      elapsed: stopwatch.elapsed,
      promptTokens: promptTokens,
      completionTokens: completionTokens,
    );
  }

  Future<void> close() async {
    if (_disposed) return;
    _disposed = true;
    _httpClient.close(force: true);
  }

  void _ensureNotDisposed() {
    if (_disposed) {
      throw const AiRuntimeException(
        code: AiErrorCode.disposed,
        stage: 'openrouter',
        message: 'The OpenRouter client was disposed.',
      );
    }
  }

  String _shortError(String payload) {
    final trimmed = payload.trim();
    if (trimmed.length <= 240) return trimmed;
    return '${trimmed.substring(0, 240)}…';
  }
}
