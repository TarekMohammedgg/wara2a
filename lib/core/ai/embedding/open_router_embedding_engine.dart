import 'dart:async';

import '../ai_runtime_error.dart';
import '../cloud/open_router_config.dart';
import '../cloud/open_router_embeddings_client.dart';
import '../model_lifecycle_state.dart';
import 'embedding_engine.dart';
import 'open_router_embedding_artifact.dart';

typedef OpenRouterApiKeyResolver = Future<String?> Function();

/// Cloud embedding engine: invoice documents + search queries via OpenRouter.
class OpenRouterEmbeddingEngine implements EmbeddingEngine {
  OpenRouterEmbeddingEngine({
    required OpenRouterApiKeyResolver resolveApiKey,
    OpenRouterEmbeddingsClient Function(String apiKey)? clientFactory,
  }) : _resolveApiKey = resolveApiKey,
       _clientFactory =
           clientFactory ??
           ((apiKey) => OpenRouterEmbeddingsClient(apiKey: apiKey));

  final OpenRouterApiKeyResolver _resolveApiKey;
  final OpenRouterEmbeddingsClient Function(String apiKey) _clientFactory;
  final _controller = StreamController<EmbeddingEngineSnapshot>.broadcast();

  OpenRouterEmbeddingsClient? _client;
  String? _clientApiKey;
  bool _cancelled = false;
  bool _disposed = false;
  EmbeddingEngineSnapshot _snapshot = const EmbeddingEngineSnapshot(
    status: ModelLifecycleStatus.notInstalled,
    capability: EmbeddingCapability.modelNotInstalled,
    modelId: OpenRouterEmbeddingArtifact.modelId,
    message: 'Add an OpenRouter API key in Settings to enable search indexing.',
  );

  @override
  EmbeddingEngineSnapshot get snapshot => _snapshot;

  @override
  Stream<EmbeddingEngineSnapshot> get snapshots => _controller.stream;

  @override
  Future<EmbeddingEngineSnapshot> refresh() async {
    _ensureNotDisposed();
    final apiKey = OpenRouterConfig.resolveApiKey(await _resolveApiKey());
    if (apiKey == null || apiKey.isEmpty) {
      return _emit(
        ModelLifecycleStatus.notInstalled,
        EmbeddingCapability.modelNotInstalled,
        message:
            'Add an OpenRouter API key in Settings to enable search indexing.',
      );
    }
    _ensureClient(apiKey);
    return _emit(
      ModelLifecycleStatus.ready,
      EmbeddingCapability.ready,
      message: 'OpenRouter embeddings are ready.',
    );
  }

  @override
  Future<void> install() async {
    await refresh();
    if (!_snapshot.canEmbed) {
      throw EmbeddingUnavailableException(
        _snapshot.message ?? 'OpenRouter API key is missing.',
      );
    }
  }

  @override
  Future<void> cancel() async {
    _cancelled = true;
  }

  @override
  Future<void> unload() async {
    // Stateless HTTP client; nothing to keep warm beyond the key binding.
  }

  @override
  Future<EmbeddingOutput> embedDocument(
    String searchableText, {
    String? title,
  }) async {
    final body = _documentText(searchableText, title: title);
    return _embed(body);
  }

  @override
  Future<EmbeddingOutput> embedQuery(String normalizedQuery) async {
    return _embed(normalizedQuery.trim());
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _client?.dispose();
    _client = null;
    await _controller.close();
  }

  Future<EmbeddingOutput> _embed(String text) async {
    _ensureNotDisposed();
    _cancelled = false;
    final availability = await refresh();
    if (!availability.canEmbed) {
      throw EmbeddingUnavailableException(
        availability.message ?? 'OpenRouter embeddings are unavailable.',
      );
    }
    if (text.length > OpenRouterEmbeddingArtifact.maximumInputCharacters) {
      throw EmbeddingInputTooLongException(
        actualCharacters: text.length,
        maximumCharacters: OpenRouterEmbeddingArtifact.maximumInputCharacters,
      );
    }
    final client = _client;
    if (client == null) {
      throw const EmbeddingUnavailableException(
        'OpenRouter embeddings client is not ready.',
      );
    }
    try {
      _emit(ModelLifecycleStatus.running, EmbeddingCapability.ready);
      final result = await client.embed(
        OpenRouterEmbeddingRequest(input: text),
        isCancelled: () => _cancelled,
      );
      if (result.dimensions != OpenRouterEmbeddingArtifact.dimensions) {
        throw EmbeddingUnavailableException(
          'Unexpected embedding dimensions: ${result.dimensions}.',
        );
      }
      _emit(ModelLifecycleStatus.ready, EmbeddingCapability.ready);
      return EmbeddingOutput(
        vector: result.vector,
        modelId: OpenRouterEmbeddingArtifact.modelId,
        dimensions: OpenRouterEmbeddingArtifact.dimensions,
        schemaVersion: OpenRouterEmbeddingArtifact.embeddingSchemaVersion,
      );
    } on AiRuntimeException catch (error) {
      if (error.code == AiErrorCode.cancelled) {
        _emit(ModelLifecycleStatus.ready, EmbeddingCapability.ready);
        rethrow;
      }
      _emit(
        ModelLifecycleStatus.failed,
        EmbeddingCapability.runtimeFailure,
        message: error.message,
      );
      throw EmbeddingUnavailableException(error.message);
    } on Object catch (error) {
      _emit(
        ModelLifecycleStatus.failed,
        EmbeddingCapability.runtimeFailure,
        message: error.toString(),
      );
      throw EmbeddingUnavailableException(error.toString());
    }
  }

  void _ensureClient(String apiKey) {
    if (_client != null && _clientApiKey == apiKey) return;
    unawaited(_client?.dispose());
    _client = _clientFactory(apiKey);
    _clientApiKey = apiKey;
  }

  String _documentText(String searchableText, {String? title}) {
    final trimmed = searchableText.trim();
    final merchant = title?.trim();
    if (merchant == null || merchant.isEmpty) return trimmed;
    return 'merchant: $merchant\n$trimmed';
  }

  EmbeddingEngineSnapshot _emit(
    ModelLifecycleStatus status,
    EmbeddingCapability capability, {
    String? message,
  }) {
    _snapshot = EmbeddingEngineSnapshot(
      status: status,
      capability: capability,
      modelId: OpenRouterEmbeddingArtifact.modelId,
      message: message,
    );
    if (!_controller.isClosed) {
      _controller.add(_snapshot);
    }
    return _snapshot;
  }

  void _ensureNotDisposed() {
    if (_disposed) {
      throw const EmbeddingUnavailableException(
        'OpenRouter embedding engine is disposed.',
      );
    }
  }
}
