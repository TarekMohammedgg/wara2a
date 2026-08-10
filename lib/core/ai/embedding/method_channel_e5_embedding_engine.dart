import 'dart:async';
import 'dart:ffi';
import 'dart:io';

import 'package:flutter/services.dart';

import '../ai_cancellation_token.dart';
import '../model_management/model_installation.dart';
import '../model_management/model_lifecycle_state.dart';
import '../model_management/secure_model_installer.dart';
import 'embedding_engine.dart';
import 'embedding_vector_validator.dart';
import 'multilingual_e5_artifact.dart';

/// Android arm64 adapter for the pinned, fully local multilingual E5 runtime.
class MethodChannelE5EmbeddingEngine implements EmbeddingEngine {
  factory MethodChannelE5EmbeddingEngine({
    required ModelInstallationLayout layout,
    MethodChannel? channel,
    SecureModelInstaller installer = const SecureModelInstaller(),
    ModelInstallationInspector inspector = const ModelInstallationInspector(),
    bool? platformSupported,
  }) => MethodChannelE5EmbeddingEngine._(
    layout,
    channel ?? const MethodChannel(_channelName),
    installer,
    inspector,
    platformSupported ?? supportsCurrentPlatform,
  );

  MethodChannelE5EmbeddingEngine._(
    this._layout,
    this._channel,
    this._installer,
    this._inspector,
    this._platformSupported,
  ) : _snapshot = const EmbeddingEngineSnapshot(
        status: ModelLifecycleStatus.notInstalled,
        capability: EmbeddingCapability.modelNotInstalled,
        modelId: MultilingualE5Artifact.modelId,
      );

  static const _channelName = 'com.wara2a.ai/embedding';

  final ModelInstallationLayout _layout;
  final MethodChannel _channel;
  final SecureModelInstaller _installer;
  final ModelInstallationInspector _inspector;
  final bool _platformSupported;
  final _controller = StreamController<EmbeddingEngineSnapshot>.broadcast();

  Future<void> _queue = Future<void>.value();
  AiCancellationToken? _installCancellation;
  bool _artifactsVerified = false;
  bool _runtimeValidated = false;
  bool _nativeOperationActive = false;
  bool _disposed = false;
  EmbeddingEngineSnapshot _snapshot;

  static bool get supportsCurrentPlatform =>
      Platform.isAndroid && Abi.current() == Abi.androidArm64;

  static Future<MethodChannelE5EmbeddingEngine> create({
    MethodChannel? channel,
    SecureModelInstaller installer = const SecureModelInstaller(),
    ModelInstallationInspector inspector = const ModelInstallationInspector(),
    ModelInstallationLayout? layout,
  }) async {
    final resolvedLayout =
        layout ?? await ModelInstallationLayout.embeddingV3();
    final engine = MethodChannelE5EmbeddingEngine(
      layout: resolvedLayout,
      channel: channel,
      installer: installer,
      inspector: inspector,
    );
    if (!engine._platformSupported) {
      engine._emit(
        ModelLifecycleStatus.unavailable,
        EmbeddingCapability.unsupportedPlatform,
        message:
            'The offline E5 runtime is currently released for Android arm64 only.',
      );
      return engine;
    }
    final model = File(
      resolvedLayout.pathFor(MultilingualE5Artifact.modelManifest),
    );
    if (await model.exists()) {
      engine._emit(
        ModelLifecycleStatus.verifying,
        EmbeddingCapability.supported,
        message: 'The installed embedding model is being verified locally.',
      );
      unawaited(engine.refresh());
    }
    return engine;
  }

  @override
  EmbeddingEngineSnapshot get snapshot => _snapshot;

  @override
  Stream<EmbeddingEngineSnapshot> get snapshots => _controller.stream;

  @override
  Future<EmbeddingEngineSnapshot> refresh() => _serialized(_refreshUnlocked);

  Future<EmbeddingEngineSnapshot> _refreshUnlocked() async {
    _ensureNotDisposed();
    if (!_platformSupported) {
      return _emit(
        ModelLifecycleStatus.unavailable,
        EmbeddingCapability.unsupportedPlatform,
        message:
            'The offline E5 runtime is currently released for Android arm64 only.',
      );
    }
    if (_artifactsVerified) {
      try {
        if (!_runtimeValidated) await _initializeNative();
        return _emit(ModelLifecycleStatus.ready, EmbeddingCapability.ready);
      } on Object catch (error) {
        _runtimeValidated = false;
        await _bestEffortNative('unload');
        return _emit(
          ModelLifecycleStatus.failed,
          EmbeddingCapability.runtimeFailure,
          message: 'The verified E5 model could not be reloaded locally: $error',
        );
      }
    }
    _emit(ModelLifecycleStatus.verifying, EmbeddingCapability.supported);
    final report = await _inspector.inspectArtifacts(
      artifacts: [MultilingualE5Artifact.modelManifest],
      layout: _layout,
    );
    if (!report.isReady) {
      _artifactsVerified = false;
      _runtimeValidated = false;
      await _bestEffortNative('unload');
      if (report.hasCorruptFile) {
        return _emit(
          ModelLifecycleStatus.failed,
          EmbeddingCapability.runtimeFailure,
          message:
              'The local E5 model failed its pinned byte-length or SHA-256 check. Reinstall it before search.',
        );
      }
      return _emitNotInstalled();
    }
    _artifactsVerified = true;
    try {
      await _initializeNative();
      return _emit(ModelLifecycleStatus.ready, EmbeddingCapability.ready);
    } on Object catch (error) {
      _runtimeValidated = false;
      await _bestEffortNative('unload');
      return _emit(
        ModelLifecycleStatus.failed,
        EmbeddingCapability.runtimeFailure,
        message: 'The verified E5 model could not be loaded locally: $error',
      );
    }
  }

  @override
  Future<void> install() => _serialized(() async {
    _ensureNotDisposed();
    if (!_platformSupported) {
      throw const EmbeddingUnavailableException(
        'The offline E5 runtime is available on Android arm64 only.',
      );
    }
    await _bestEffortNative('unload');
    _runtimeValidated = false;
    final cancellation = AiCancellationToken();
    _installCancellation = cancellation;
    try {
      await _installer.installArtifacts(
        artifacts: [MultilingualE5Artifact.modelManifest],
        schemaVersion: MultilingualE5Artifact.embeddingSchemaVersion,
        layout: _layout,
        cancellationToken: cancellation,
        onProgress: (progress) {
          final status = switch (progress.stage) {
            ModelInstallStage.checkingStorage ||
            ModelInstallStage.downloading => ModelLifecycleStatus.downloading,
            ModelInstallStage.verifying ||
            ModelInstallStage.activating => ModelLifecycleStatus.verifying,
            ModelInstallStage.completed => ModelLifecycleStatus.loading,
          };
          _emit(
            status,
            EmbeddingCapability.supported,
            progress: progress.fraction,
          );
        },
      );
      cancellation.throwIfCancelled();
      final refreshed = await _refreshUnlocked();
      if (!refreshed.canEmbed) {
        throw EmbeddingUnavailableException(
          refreshed.message ?? 'The E5 runtime did not become ready.',
        );
      }
    } on AiCancelledException {
      final report = await _inspector.inspectArtifacts(
        artifacts: [MultilingualE5Artifact.modelManifest],
        layout: _layout,
      );
      if (report.isReady) {
        _artifactsVerified = true;
        try {
          await _initializeNative();
          _emit(
            ModelLifecycleStatus.ready,
            EmbeddingCapability.ready,
            message:
                'Installation was cancelled; the previous verified E5 model remains active.',
          );
        } on AiCancelledException {
          _emit(ModelLifecycleStatus.ready, EmbeddingCapability.ready);
          rethrow;
        } on Object {
          _runtimeValidated = false;
          _emit(
            ModelLifecycleStatus.failed,
            EmbeddingCapability.runtimeFailure,
            message:
                'Installation was cancelled and the remaining model could not be loaded.',
          );
        }
      } else {
        _artifactsVerified = false;
        _emitNotInstalled(message: 'E5 model installation was cancelled.');
      }
      rethrow;
    } on Object {
      if (_snapshot.status != ModelLifecycleStatus.failed) {
        _emit(
          ModelLifecycleStatus.failed,
          EmbeddingCapability.runtimeFailure,
          message:
              'E5 installation, integrity verification, or local load failed.',
        );
      }
      rethrow;
    } finally {
      if (identical(_installCancellation, cancellation)) {
        _installCancellation = null;
      }
    }
  });

  @override
  Future<void> cancel() async {
    if (_disposed) return;
    final installCancellation = _installCancellation;
    if (installCancellation != null || _nativeOperationActive) {
      _emit(ModelLifecycleStatus.cancelling, EmbeddingCapability.supported);
    }
    installCancellation?.cancel();
    await _bestEffortNative('cancel');
  }

  @override
  Future<EmbeddingOutput> embedDocument(
    String searchableText, {
    String? title,
  }) {
    _validateInput(searchableText);
    return _embed(
      MultilingualE5Artifact.formatDocument(searchableText, title: title),
    );
  }

  @override
  Future<EmbeddingOutput> embedQuery(String normalizedQuery) {
    _validateInput(normalizedQuery);
    return _embed(MultilingualE5Artifact.formatQuery(normalizedQuery));
  }

  Future<EmbeddingOutput> _embed(String prefixedText) => _serialized(() async {
    _ensureNotDisposed();
    if (!_platformSupported) {
      throw const EmbeddingUnavailableException(
        'The offline E5 runtime is available on Android arm64 only.',
      );
    }
    if (!_artifactsVerified) {
      final refreshed = await _refreshUnlocked();
      if (!refreshed.canEmbed) {
        throw EmbeddingUnavailableException(
          refreshed.message ?? 'The E5 model is not ready.',
        );
      }
    } else if (!_runtimeValidated) {
      await _initializeNative();
    }
    _emit(ModelLifecycleStatus.running, EmbeddingCapability.ready);
    _nativeOperationActive = true;
    try {
      final response = await _invokeMap('embed', <String, Object?>{
        'text': prefixedText,
      });
      final dimensions = response['dimensions'];
      final modelId = response['modelId'];
      final raw = response['embedding'];
      if (dimensions != MultilingualE5Artifact.dimensions ||
          modelId != MultilingualE5Artifact.modelId ||
          raw is! List<Object?>) {
        throw const EmbeddingUnavailableException(
          'The native E5 bridge returned incompatible embedding metadata.',
        );
      }
      final values = raw.map((value) {
        if (value is! num) {
          throw const InvalidEmbeddingVector(
            'Every native embedding value must be numeric.',
          );
        }
        return value.toDouble();
      });
      final vector = EmbeddingVectorValidator.normalizeAndValidate(
        values,
        dimensions: MultilingualE5Artifact.dimensions,
      );
      _runtimeValidated = true;
      _emit(ModelLifecycleStatus.ready, EmbeddingCapability.ready);
      return EmbeddingOutput(
        vector: vector,
        modelId: MultilingualE5Artifact.modelId,
        dimensions: MultilingualE5Artifact.dimensions,
        schemaVersion: MultilingualE5Artifact.embeddingSchemaVersion,
      );
    } on Object {
      if (!_disposed) {
        _emit(
          ModelLifecycleStatus.failed,
          EmbeddingCapability.runtimeFailure,
          message: 'Local E5 inference failed.',
        );
      }
      rethrow;
    } finally {
      _nativeOperationActive = false;
    }
  });

  Future<void> _initializeNative() async {
    _emit(ModelLifecycleStatus.loading, EmbeddingCapability.supported);
    final response = await _invokeMap('initialize', <String, Object?>{
      'modelPath': _layout.pathFor(MultilingualE5Artifact.modelManifest),
    });
    if (response['dimensions'] != MultilingualE5Artifact.dimensions ||
        response['modelId'] != MultilingualE5Artifact.modelId ||
        response['tokenizerBytes'] !=
            MultilingualE5Artifact.tokenizerGraphByteLength ||
        response['tokenizerSha256'] !=
            MultilingualE5Artifact.tokenizerGraphSha256) {
      throw const EmbeddingUnavailableException(
        'The native E5 runtime reported an incompatible model contract.',
      );
    }
    _runtimeValidated = true;
  }

  @override
  Future<void> unload() => _serialized(() async {
    if (_disposed) return;
    if (!_platformSupported) return;
    await _invokeVoid('unload');
    _runtimeValidated = false;
    if (_artifactsVerified) {
      _emit(ModelLifecycleStatus.ready, EmbeddingCapability.ready);
    } else {
      _emitNotInstalled();
    }
  });

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _installCancellation?.cancel();
    await _bestEffortNative('cancel');
    await _queue;
    await _bestEffortNative('dispose');
    _runtimeValidated = false;
    _emit(ModelLifecycleStatus.disposed, EmbeddingCapability.supported);
    await _controller.close();
  }

  Future<Map<Object?, Object?>> _invokeMap(
    String method, [
    Object? arguments,
  ]) async {
    try {
      final response = await _channel.invokeMethod<Object?>(method, arguments);
      if (response is! Map<Object?, Object?>) {
        throw EmbeddingUnavailableException(
          'The native E5 $method response was not an object.',
        );
      }
      return response;
    } on MissingPluginException catch (error) {
      throw EmbeddingUnavailableException(
        'The Android E5 bridge is not registered: $error',
      );
    } on PlatformException catch (error) {
      if (error.code == 'cancelled') throw const AiCancelledException();
      if (error.code == 'input_too_long') {
        final details = error.details;
        final actualTokens = details is Map<Object?, Object?>
            ? details['actualTokens']
            : null;
        final maximumTokens = details is Map<Object?, Object?>
            ? details['maximumTokens']
            : null;
        throw EmbeddingInputTooLongException.tokens(
          actualTokens: actualTokens is int ? actualTokens : 513,
          maximumTokens: maximumTokens is int
              ? maximumTokens
              : MultilingualE5Artifact.maximumSequenceTokens,
        );
      }
      throw EmbeddingUnavailableException(
        error.message ?? 'The Android E5 runtime failed during $method.',
      );
    }
  }

  Future<void> _invokeVoid(String method) async {
    try {
      await _channel.invokeMethod<void>(method);
    } on MissingPluginException catch (error) {
      throw EmbeddingUnavailableException(
        'The Android E5 bridge is not registered: $error',
      );
    } on PlatformException catch (error) {
      if (error.code == 'cancelled') throw const AiCancelledException();
      throw EmbeddingUnavailableException(
        error.message ?? 'The Android E5 runtime failed during $method.',
      );
    }
  }

  Future<void> _bestEffortNative(String method) async {
    if (!_platformSupported) return;
    try {
      await _channel.invokeMethod<void>(method);
    } on Object {
      // Cleanup must preserve the primary install, integrity, or inference error.
    }
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
      modelId: MultilingualE5Artifact.modelId,
      progress: progress,
      message: message,
    );
    _snapshot = next;
    if (!_controller.isClosed) _controller.add(next);
    return next;
  }

  EmbeddingEngineSnapshot _emitNotInstalled({String? message}) => _emit(
    ModelLifecycleStatus.notInstalled,
    EmbeddingCapability.modelNotInstalled,
    message: message,
  );

  void _validateInput(String input) {
    if (input.trim().isEmpty) {
      throw const EmbeddingUnavailableException(
        'Embedding input must not be empty.',
      );
    }
    if (input.length > MultilingualE5Artifact.maximumInputCharacters) {
      throw EmbeddingInputTooLongException(
        actualCharacters: input.length,
        maximumCharacters: MultilingualE5Artifact.maximumInputCharacters,
      );
    }
  }

  void _ensureNotDisposed() {
    if (_disposed) {
      throw const EmbeddingUnavailableException(
        'The E5 embedding engine has been disposed.',
      );
    }
  }
}
