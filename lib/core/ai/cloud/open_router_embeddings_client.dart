import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../ai_runtime_error.dart';
import '../embedding/open_router_embedding_artifact.dart';

class OpenRouterEmbeddingRequest {
  const OpenRouterEmbeddingRequest({required this.input, this.modelId});

  final String input;
  final String? modelId;
}

class OpenRouterEmbeddingResult {
  const OpenRouterEmbeddingResult({
    required this.vector,
    required this.modelId,
    required this.dimensions,
  });

  final List<double> vector;
  final String modelId;
  final int dimensions;
}

/// OpenAI-compatible embeddings client against OpenRouter.
class OpenRouterEmbeddingsClient {
  OpenRouterEmbeddingsClient({
    required this.apiKey,
    this.baseUrl = OpenRouterEmbeddingArtifact.defaultBaseUrl,
    this.modelId = OpenRouterEmbeddingArtifact.modelId,
    this.timeout = const Duration(seconds: 45),
    HttpClient? httpClient,
  }) : _httpClient = httpClient ?? HttpClient();

  final String apiKey;
  final String baseUrl;
  final String modelId;
  final Duration timeout;
  final HttpClient _httpClient;
  bool _disposed = false;

  Future<OpenRouterEmbeddingResult> embed(
    OpenRouterEmbeddingRequest request, {
    bool Function()? isCancelled,
  }) async {
    _ensureNotDisposed();
    final input = request.input.trim();
    if (input.isEmpty) {
      throw const AiRuntimeException(
        code: AiErrorCode.invalidModelOutput,
        stage: 'openrouter-embeddings',
        message: 'Embedding input must not be empty.',
      );
    }

    late final HttpClientRequest httpRequest;
    try {
      httpRequest = await _httpClient
          .postUrl(Uri.parse(baseUrl))
          .timeout(timeout);
    } on TimeoutException catch (error) {
      throw AiRuntimeException(
        code: AiErrorCode.timeout,
        stage: 'openrouter-embeddings',
        message: 'OpenRouter embeddings connection timed out.',
        cause: error,
      );
    } on Object catch (error) {
      throw AiRuntimeException(
        code: AiErrorCode.inferenceFailed,
        stage: 'openrouter-embeddings',
        message: 'Could not reach OpenRouter embeddings.',
        cause: error,
      );
    }

    final body = <String, Object?>{
      'model': request.modelId ?? modelId,
      'input': input,
    };
    httpRequest.headers.set(HttpHeaders.authorizationHeader, 'Bearer $apiKey');
    httpRequest.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
    httpRequest.headers.set(HttpHeaders.acceptHeader, 'application/json');
    httpRequest.headers.set('HTTP-Referer', 'https://wara2a.app');
    httpRequest.headers.set('X-Title', 'wara2a');
    httpRequest.add(utf8.encode(jsonEncode(body)));

    if (isCancelled?.call() == true) {
      httpRequest.abort();
      throw const AiRuntimeException(
        code: AiErrorCode.cancelled,
        stage: 'openrouter-embeddings',
        message: 'Embedding request was cancelled.',
      );
    }

    final HttpClientResponse response;
    try {
      response = await httpRequest.close().timeout(timeout);
    } on TimeoutException catch (error) {
      throw AiRuntimeException(
        code: AiErrorCode.timeout,
        stage: 'openrouter-embeddings',
        message: 'OpenRouter embeddings response timed out.',
        cause: error,
      );
    }

    final raw = await response.transform(utf8.decoder).join();
    if (isCancelled?.call() == true) {
      throw const AiRuntimeException(
        code: AiErrorCode.cancelled,
        stage: 'openrouter-embeddings',
        message: 'Embedding request was cancelled.',
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AiRuntimeException(
        code: AiErrorCode.inferenceFailed,
        stage: 'openrouter-embeddings',
        message:
            'OpenRouter embeddings failed (${response.statusCode}): '
            '${raw.length > 240 ? '${raw.substring(0, 240)}…' : raw}',
      );
    }

    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw const AiRuntimeException(
        code: AiErrorCode.inferenceFailed,
        stage: 'openrouter-embeddings',
        message: 'OpenRouter embeddings returned a non-object payload.',
      );
    }
    final data = decoded['data'];
    if (data is! List || data.isEmpty || data.first is! Map) {
      throw const AiRuntimeException(
        code: AiErrorCode.inferenceFailed,
        stage: 'openrouter-embeddings',
        message: 'OpenRouter embeddings payload had no vectors.',
      );
    }
    final first = Map<String, dynamic>.from(data.first as Map);
    final embedding = first['embedding'];
    if (embedding is! List || embedding.isEmpty) {
      throw const AiRuntimeException(
        code: AiErrorCode.inferenceFailed,
        stage: 'openrouter-embeddings',
        message: 'OpenRouter embeddings vector was empty.',
      );
    }
    final vector = embedding
        .map((value) => (value as num).toDouble())
        .toList(growable: false);
    final resolvedModel =
        (decoded['model'] as String?)?.trim().isNotEmpty == true
        ? (decoded['model'] as String).trim()
        : (request.modelId ?? modelId);
    return OpenRouterEmbeddingResult(
      vector: vector,
      modelId: resolvedModel,
      dimensions: vector.length,
    );
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _httpClient.close(force: true);
  }

  void _ensureNotDisposed() {
    if (_disposed) {
      throw const AiRuntimeException(
        code: AiErrorCode.inferenceFailed,
        stage: 'openrouter-embeddings',
        message: 'OpenRouter embeddings client is disposed.',
      );
    }
  }
}
