import 'dart:async';
import 'dart:ffi';
import 'dart:io';

import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_gemma_embeddings/flutter_gemma_embeddings.dart';

import 'embedding_engine.dart';
import 'embedding_gemma_artifact.dart';
import 'embedding_vector_validator.dart';
import '../model_management/model_lifecycle_state.dart';
import '../model_management/model_file_verifier.dart';

class FlutterGemmaEmbeddingEngine implements EmbeddingEngine {
  FlutterGemmaEmbeddingEngine._({required this.accessToken})
    : _snapshot = EmbeddingEngineSnapshot(
        status: ModelLifecycleStatus.notInstalled,
        capability: EmbeddingCapability.modelNotInstalled,
        modelId: EmbeddingGemmaArtifact.modelId,
      );

  final String? accessToken;
  final _controller = StreamController<EmbeddingEngineSnapshot>.broadcast();
  Future<void> _queue = Future<void>.value();
  EmbeddingModel? _model;
  CancelToken? _cancelToken;
  bool _artifactsVerified = false;
  bool _runtimeValidated = false;
  bool _disposed = false;
  EmbeddingEngineSnapshot _snapshot;

  static Future<FlutterGemmaEmbeddingEngine> create({
    String? accessToken,
  }) async {
    await FlutterGemma.initialize(
      huggingFaceToken: accessToken,
      embeddingBackends: const [LiteRtEmbeddingBackend()],
    );
    FlutterGemma.logLevel = GemmaLogLevel.none;
    final engine = FlutterGemmaEmbeddingEngine._(accessToken: accessToken);
    if (!supportsCurrentPlatform) {
      engine._emit(
        ModelLifecycleStatus.unavailable,
        EmbeddingCapability.unsupportedPlatform,
        message: 'EmbeddingGemma requires a supported native CPU architecture.',
      );
    } else if (FlutterGemma.hasActiveEmbedder()) {
      // Hashing roughly 184 MB and loading LiteRT are intentionally deferred
      // until Settings, indexing, or search requests an authoritative refresh.
      engine._emit(
        ModelLifecycleStatus.verifying,
        EmbeddingCapability.supported,
        message: 'The installed embedding model still requires verification.',
      );
    } else {
      engine._emitNotInstalled();
    }
    return engine;
  }

  @override
  EmbeddingEngineSnapshot get snapshot => _snapshot;

  @override
  Stream<EmbeddingEngineSnapshot> get snapshots => _controller.stream;

  @override
  Future<EmbeddingEngineSnapshot> refresh() => _serialized(() async {
    _ensureNotDisposed();
    if (!supportsCurrentPlatform) {
      return _emit(
        ModelLifecycleStatus.unavailable,
        EmbeddingCapability.unsupportedPlatform,
        message: 'EmbeddingGemma requires a supported native CPU architecture.',
      );
    }
    if (!FlutterGemma.hasActiveEmbedder()) {
      _artifactsVerified = false;
      _runtimeValidated = false;
      await _closeLoadedModel();
      return _emitNotInstalled();
    }
    if (!_artifactsVerified) {
      _emit(ModelLifecycleStatus.verifying, EmbeddingCapability.supported);
      final verified = await _verifyActiveArtifacts();
      if (!verified) {
        _artifactsVerified = false;
        _runtimeValidated = false;
        await _closeLoadedModel();
        try {
          await FlutterGemma.uninstallEmbedder();
        } on Object {
          return _emit(
            ModelLifecycleStatus.failed,
            EmbeddingCapability.runtimeFailure,
            message:
                'Installed EmbeddingGemma files failed integrity checks and could not be removed.',
          );
        }
        return _emitNotInstalled(
          message:
              'Corrupt EmbeddingGemma files were removed. Install the verified artifact set again.',
        );
      }
      _artifactsVerified = true;
    }
    if (!_runtimeValidated) {
      try {
        await _loadModel();
      } on Object {
        _runtimeValidated = false;
        await _closeLoadedModel();
        return _emit(
          ModelLifecycleStatus.failed,
          EmbeddingCapability.runtimeFailure,
          message:
              'The verified EmbeddingGemma files could not be loaded by the local runtime.',
        );
      }
    }
    return _emit(ModelLifecycleStatus.ready, EmbeddingCapability.ready);
  });

  @override
  Future<void> install() => _serialized(() async {
    _ensureNotDisposed();
    if (!supportsCurrentPlatform) {
      throw const EmbeddingUnavailableException(
        'EmbeddingGemma is unsupported on this native architecture.',
      );
    }
    final token = accessToken;
    if (EmbeddingGemmaArtifact.requiresAcceptedLicenseAndToken &&
        (token == null || token.isEmpty)) {
      _emit(
        ModelLifecycleStatus.unavailable,
        EmbeddingCapability.modelAccessRequired,
        message: 'EmbeddingGemma model access is not configured.',
      );
      throw const EmbeddingUnavailableException(
        'Accept the EmbeddingGemma license and provide authorized model access.',
      );
    }

    await _closeLoadedModel();
    _artifactsVerified = false;
    _runtimeValidated = false;
    _cancelToken = CancelToken();
    _emit(
      ModelLifecycleStatus.downloading,
      EmbeddingCapability.supported,
      progress: 0,
    );
    try {
      final installation = await FlutterGemma.installEmbedder()
          .modelFromNetwork(EmbeddingGemmaArtifact.modelUrl, token: token)
          .tokenizerFromNetwork(
            EmbeddingGemmaArtifact.tokenizerUrl,
            token: token,
          )
          .withModelProgress(
            (progress) => _emit(
              ModelLifecycleStatus.downloading,
              EmbeddingCapability.supported,
              progress: progress * 0.009,
            ),
          )
          .withTokenizerProgress(
            (progress) => _emit(
              ModelLifecycleStatus.downloading,
              EmbeddingCapability.supported,
              progress: 0.9 + progress * 0.001,
            ),
          )
          .withCancelToken(_cancelToken!)
          .install();
      _emit(
        ModelLifecycleStatus.verifying,
        EmbeddingCapability.supported,
        progress: 1,
      );
      final verified = await _verifyArtifacts(installation.spec.files);
      if (!verified) {
        await FlutterGemma.uninstallEmbedder();
        throw const _EmbeddingArtifactIntegrityException(
          'Downloaded EmbeddingGemma files failed byte-length or SHA-256 verification.',
        );
      }
      _artifactsVerified = true;
      await _loadModel();
      _emit(ModelLifecycleStatus.ready, EmbeddingCapability.ready);
    } catch (error) {
      if (CancelToken.isCancel(error)) {
        _artifactsVerified = false;
        final installed = FlutterGemma.hasActiveEmbedder();
        if (installed) {
          _emit(ModelLifecycleStatus.verifying, EmbeddingCapability.supported);
          final verified = await _verifyActiveArtifacts();
          _artifactsVerified = verified;
          if (verified) {
            try {
              await _loadModel();
              _emit(
                ModelLifecycleStatus.ready,
                EmbeddingCapability.ready,
                message:
                    'Embedding model installation was cancelled; the previous verified model remains active.',
              );
            } on Object {
              await _closeLoadedModel();
              _emit(
                ModelLifecycleStatus.failed,
                EmbeddingCapability.runtimeFailure,
                message:
                    'Embedding installation was cancelled and the remaining model could not be loaded.',
              );
            }
          } else {
            await _closeLoadedModel();
            try {
              await FlutterGemma.uninstallEmbedder();
              _emitNotInstalled(
                message:
                    'Embedding installation was cancelled and incomplete files were removed.',
              );
            } on Object {
              _emit(
                ModelLifecycleStatus.failed,
                EmbeddingCapability.runtimeFailure,
                message:
                    'Embedding installation was cancelled, but incomplete files could not be removed.',
              );
            }
          }
        } else {
          _emitNotInstalled(
            message: 'Embedding model installation was cancelled.',
          );
        }
      } else if (error is _EmbeddingArtifactIntegrityException) {
        _artifactsVerified = false;
        _runtimeValidated = false;
        _emitNotInstalled(message: error.message);
      } else {
        _emit(
          ModelLifecycleStatus.failed,
          EmbeddingCapability.runtimeFailure,
          message:
              'Embedding model installation or local runtime validation failed.',
        );
      }
      rethrow;
    } finally {
      _cancelToken = null;
    }
  });

  @override
  Future<void> cancel() async {
    final token = _cancelToken;
    if (token == null) return;
    _emit(ModelLifecycleStatus.cancelling, EmbeddingCapability.supported);
    token.cancel('Embedding model installation cancelled.');
  }

  @override
  Future<EmbeddingOutput> embedDocument(String searchableText) {
    _validateInput(
      searchableText,
      maximumCharacters: EmbeddingGemmaArtifact.maximumDocumentCharacters,
    );
    // flutter_gemma_embeddings 1.0.4 owns the exact retrieval prefixes. It
    // emits `title: none | text:` for documents, so preformatting a title here
    // would double-prefix the input. Merchant remains in the deterministic
    // document body until the adapter exposes a custom-title contract.
    return _embed(searchableText, taskType: TaskType.retrievalDocument);
  }

  @override
  Future<EmbeddingOutput> embedQuery(String normalizedQuery) {
    _validateInput(
      normalizedQuery,
      maximumCharacters: EmbeddingGemmaArtifact.maximumQueryCharacters,
    );
    return _embed(normalizedQuery, taskType: TaskType.retrievalQuery);
  }

  Future<EmbeddingOutput> _embed(
    String value, {
    required TaskType taskType,
  }) => _serialized(() async {
    _ensureNotDisposed();
    if (!FlutterGemma.hasActiveEmbedder()) {
      _emit(
        ModelLifecycleStatus.notInstalled,
        EmbeddingCapability.modelNotInstalled,
      );
      throw const EmbeddingUnavailableException(
        'EmbeddingGemma is not installed.',
      );
    }
    try {
      final model = await _loadModel();
      _emit(ModelLifecycleStatus.running, EmbeddingCapability.ready);
      final raw = await model.generateEmbedding(value, taskType: taskType);
      final vector = EmbeddingVectorValidator.normalizeAndValidate(
        raw,
        dimensions: EmbeddingGemmaArtifact.dimensions,
      );
      _emit(ModelLifecycleStatus.ready, EmbeddingCapability.ready);
      return EmbeddingOutput(
        vector: vector,
        modelId: EmbeddingGemmaArtifact.modelId,
        dimensions: EmbeddingGemmaArtifact.dimensions,
        schemaVersion: EmbeddingGemmaArtifact.embeddingSchemaVersion,
      );
    } catch (error) {
      _runtimeValidated = false;
      await _closeLoadedModel();
      _emit(
        ModelLifecycleStatus.failed,
        EmbeddingCapability.runtimeFailure,
        message:
            'The local EmbeddingGemma runtime failed while generating an embedding.',
      );
      rethrow;
    }
  });

  Future<EmbeddingModel> _loadModel() async {
    final existing = _model;
    if (existing != null) return existing;
    _emit(ModelLifecycleStatus.loading, EmbeddingCapability.supported);
    EmbeddingModel? candidate;
    try {
      candidate = await FlutterGemma.getActiveEmbedder(
        preferredBackend: PreferredBackend.cpu,
      );
      final dimensions = await candidate.getDimension();
      if (dimensions != EmbeddingGemmaArtifact.dimensions) {
        throw InvalidEmbeddingVector(
          'Installed model reports $dimensions dimensions; expected '
          '${EmbeddingGemmaArtifact.dimensions}.',
        );
      }
      _model = candidate;
      _runtimeValidated = true;
      return candidate;
    } catch (_) {
      _runtimeValidated = false;
      if (candidate != null) {
        try {
          await candidate.close();
        } on Object {
          // Preserve the load/dimension error; the engine remains unavailable.
        }
      }
      rethrow;
    }
  }

  @override
  Future<void> unload() => _serialized(() async {
    await _closeLoadedModel();
    if (_disposed) return;
    if (FlutterGemma.hasActiveEmbedder() &&
        _artifactsVerified &&
        _runtimeValidated) {
      _emit(ModelLifecycleStatus.ready, EmbeddingCapability.ready);
    } else if (!FlutterGemma.hasActiveEmbedder()) {
      _emit(
        ModelLifecycleStatus.notInstalled,
        accessToken == null || accessToken!.isEmpty
            ? EmbeddingCapability.modelAccessRequired
            : EmbeddingCapability.modelNotInstalled,
      );
    }
  });

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _cancelToken?.cancel('Embedding engine disposed.');
    await _queue;
    await _closeLoadedModel();
    _emit(ModelLifecycleStatus.disposed, EmbeddingCapability.supported);
    await _controller.close();
  }

  Future<T> _serialized<T>(Future<T> Function() operation) {
    final completer = Completer<T>();
    _queue = _queue.then((_) async {
      try {
        completer.complete(await operation());
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  EmbeddingEngineSnapshot _emit(
    ModelLifecycleStatus status,
    EmbeddingCapability capability, {
    double? progress,
    String? message,
  }) {
    final next = EmbeddingEngineSnapshot(
      status: status,
      capability: capability,
      modelId: EmbeddingGemmaArtifact.modelId,
      progress: progress,
      message: message,
    );
    _snapshot = next;
    if (!_controller.isClosed) _controller.add(next);
    return next;
  }

  void _ensureNotDisposed() {
    if (_disposed) {
      throw const EmbeddingUnavailableException(
        'Embedding engine is disposed.',
      );
    }
  }

  Future<void> _closeLoadedModel() async {
    final model = _model;
    _model = null;
    if (model != null) await model.close();
  }

  EmbeddingEngineSnapshot _emitNotInstalled({String? message}) {
    final accessRequired = accessToken == null || accessToken!.isEmpty;
    return _emit(
      ModelLifecycleStatus.notInstalled,
      accessRequired
          ? EmbeddingCapability.modelAccessRequired
          : EmbeddingCapability.modelNotInstalled,
      message:
          message ??
          (accessRequired
              ? 'Accept the EmbeddingGemma license and configure an approved model source.'
              : null),
    );
  }

  static void _validateInput(String value, {required int maximumCharacters}) {
    final length = value.runes.length;
    if (value.trim().isEmpty) {
      throw const EmbeddingUnavailableException(
        'Embedding input must not be empty.',
      );
    }
    if (length > maximumCharacters) {
      throw EmbeddingInputTooLongException(
        actualCharacters: length,
        maximumCharacters: maximumCharacters,
      );
    }
  }

  Future<bool> _verifyActiveArtifacts() async {
    final spec = FlutterGemma.activeEmbedderSpec;
    if (spec == null) return false;
    return _verifyArtifacts(spec.files);
  }

  Future<bool> _verifyArtifacts(List<ModelFile> files) async {
    if (files.length != 2) return false;
    final modelPath = await FlutterGemma.getModelPath(files[0].filename);
    final tokenizerPath = await FlutterGemma.getModelPath(files[1].filename);
    final verifier = const ModelFileVerifier();
    final results = await Future.wait([
      verifier.verify(
        artifact: EmbeddingGemmaArtifact.modelManifest,
        path: modelPath,
      ),
      verifier.verify(
        artifact: EmbeddingGemmaArtifact.tokenizerManifest,
        path: tokenizerPath,
      ),
    ]);
    return results.every((result) => result.isVerified);
  }

  static bool get supportsCurrentPlatform {
    final abi = Abi.current().toString().toLowerCase();
    if (Platform.isAndroid) return abi.contains('androidarm64');
    if (Platform.isIOS) return abi.contains('iosarm64');
    if (Platform.isWindows) return abi.contains('windowsx64');
    if (Platform.isMacOS) return abi.contains('macosarm64');
    if (Platform.isLinux) {
      return abi.contains('linuxx64') || abi.contains('linuxarm64');
    }
    return false;
  }
}

class _EmbeddingArtifactIntegrityException
    extends EmbeddingUnavailableException {
  const _EmbeddingArtifactIntegrityException(super.message);
}
