import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

import '../ai_cancellation_token.dart';
import '../ai_runtime_error.dart';
import 'model_file_verifier.dart';
import 'model_installation.dart';
import 'model_manifest.dart';

enum ModelInstallStage {
  checkingStorage,
  downloading,
  verifying,
  activating,
  completed,
}

class ModelInstallProgress {
  const ModelInstallProgress({
    required this.stage,
    required this.completedBytes,
    required this.totalBytes,
    this.artifact,
  });

  final ModelInstallStage stage;
  final int completedBytes;
  final int totalBytes;
  final ModelArtifactManifest? artifact;

  double get fraction => totalBytes == 0
      ? 1
      : (completedBytes / totalBytes).clamp(0, 1).toDouble();
}

typedef ModelInstallProgressCallback =
    void Function(ModelInstallProgress progress);

abstract interface class ModelStorageProbe {
  Future<int?> availableBytes(String path);
}

class PlatformModelStorageProbe implements ModelStorageProbe {
  const PlatformModelStorageProbe({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(_channelName);

  static const String _channelName = 'com.wara2a.ai/models';
  final MethodChannel _channel;

  @override
  Future<int?> availableBytes(String path) async {
    if (!Platform.isAndroid) return null;
    try {
      return await _channel.invokeMethod<int>(
        'availableBytes',
        <String, String>{'path': path},
      );
    } on MissingPluginException {
      return null;
    } on PlatformException catch (error) {
      throw AiRuntimeException(
        code: AiErrorCode.initializationFailed,
        stage: 'model-storage',
        message: error.message ?? 'Unable to inspect model storage.',
        cause: error,
      );
    }
  }
}

abstract interface class ModelArtifactTransfer {
  Future<void> download({
    required ModelArtifactManifest artifact,
    required File destination,
    required void Function(int receivedBytes) onProgress,
    AiCancellationToken? cancellationToken,
  });
}

class HttpsModelArtifactTransfer implements ModelArtifactTransfer {
  const HttpsModelArtifactTransfer({
    this.connectionTimeout = const Duration(seconds: 20),
    this.idleTimeout = const Duration(seconds: 30),
  });

  final Duration connectionTimeout;
  final Duration idleTimeout;

  @override
  Future<void> download({
    required ModelArtifactManifest artifact,
    required File destination,
    required void Function(int receivedBytes) onProgress,
    AiCancellationToken? cancellationToken,
  }) async {
    if (!artifact.sourceUri.isScheme('https')) {
      throw const AiRuntimeException(
        code: AiErrorCode.modelVerificationFailed,
        stage: 'model-download',
        message: 'Model downloads require HTTPS.',
      );
    }
    final client = HttpClient()
      ..connectionTimeout = connectionTimeout
      ..userAgent = 'Wara2a/1.0 offline-model-installer';
    IOSink? sink;
    try {
      cancellationToken?.throwIfCancelled();
      final request = await client.getUrl(artifact.sourceUri);
      request.followRedirects = true;
      request.maxRedirects = 5;
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        throw AiRuntimeException(
          code: AiErrorCode.modelNotInstalled,
          stage: 'model-download',
          message:
              'Model host returned HTTP ${response.statusCode} for ${artifact.modelId}.',
        );
      }
      if (response.redirects.any(
        (redirect) => !redirect.location.isScheme('https'),
      )) {
        throw const AiRuntimeException(
          code: AiErrorCode.modelVerificationFailed,
          stage: 'model-download',
          message: 'A model download redirected outside HTTPS.',
        );
      }
      if (response.contentLength >= 0 &&
          response.contentLength != artifact.byteLength) {
        throw AiRuntimeException(
          code: AiErrorCode.modelVerificationFailed,
          stage: 'model-download',
          message:
              'The model host reported an unexpected byte length for ${artifact.modelId}.',
        );
      }

      sink = destination.openWrite(mode: FileMode.writeOnly);
      var received = 0;
      await for (final chunk in response.timeout(idleTimeout)) {
        cancellationToken?.throwIfCancelled();
        received += chunk.length;
        if (received > artifact.byteLength) {
          throw AiRuntimeException(
            code: AiErrorCode.modelVerificationFailed,
            stage: 'model-download',
            message: 'The model download exceeded its pinned byte length.',
          );
        }
        sink.add(chunk);
        onProgress(received);
      }
      await sink.flush();
      await sink.close();
      sink = null;
      cancellationToken?.throwIfCancelled();
      if (received != artifact.byteLength) {
        throw AiRuntimeException(
          code: AiErrorCode.modelVerificationFailed,
          stage: 'model-download',
          message: 'The model download ended before its pinned byte length.',
        );
      }
    } on TimeoutException catch (error) {
      throw AiRuntimeException(
        code: AiErrorCode.timeout,
        stage: 'model-download',
        message: 'The model download stopped receiving data.',
        cause: error,
      );
    } on SocketException catch (error) {
      throw AiRuntimeException(
        code: AiErrorCode.modelNotInstalled,
        stage: 'model-download',
        message:
            'The model host could not be reached. Check this device network and retry the explicit install.',
        cause: error,
      );
    } on HttpException catch (error) {
      throw AiRuntimeException(
        code: AiErrorCode.modelNotInstalled,
        stage: 'model-download',
        message: 'The model download could not be completed over HTTPS.',
        cause: error,
      );
    } finally {
      await sink?.close();
      client.close(force: true);
    }
  }
}

class SecureModelInstaller {
  const SecureModelInstaller({
    this.transfer = const HttpsModelArtifactTransfer(),
    this.verifier = const ModelFileVerifier(),
    this.storageProbe = const PlatformModelStorageProbe(),
    this.freeSpaceReserveBytes = 64 * 1024 * 1024,
  });

  final ModelArtifactTransfer transfer;
  final ModelFileVerifier verifier;
  final ModelStorageProbe storageProbe;
  final int freeSpaceReserveBytes;

  Future<void> installRequired({
    required Phase7ModelManifest manifest,
    required ModelInstallationLayout layout,
    required ModelInstallProgressCallback onProgress,
    AiCancellationToken? cancellationToken,
  }) async {
    final artifacts = requiredPhase7ArtifactIds
        .map(manifest.byId)
        .toList(growable: false);
    await installArtifacts(
      artifacts: artifacts,
      schemaVersion: manifest.schemaVersion,
      layout: layout,
      onProgress: onProgress,
      cancellationToken: cancellationToken,
    );
  }

  Future<void> installArtifacts({
    required List<ModelArtifactManifest> artifacts,
    required int schemaVersion,
    required ModelInstallationLayout layout,
    required ModelInstallProgressCallback onProgress,
    AiCancellationToken? cancellationToken,
  }) async {
    if (artifacts.isEmpty) {
      throw const AiRuntimeException(
        code: AiErrorCode.incompatibleArtifact,
        stage: 'model-install',
        message: 'The requested model artifact set is empty.',
      );
    }
    if (artifacts.any((artifact) => !artifact.installable)) {
      throw const AiRuntimeException(
        code: AiErrorCode.incompatibleArtifact,
        stage: 'model-install',
        message: 'The required model set contains a non-installable artifact.',
      );
    }
    await layout.rootDirectory.create(recursive: true);
    final existing = <String, ModelFileVerification>{};
    var verifiedBytes = 0;
    for (final artifact in artifacts) {
      cancellationToken?.throwIfCancelled();
      final result = await verifier.verify(
        artifact: artifact,
        path: layout.pathFor(artifact),
        cancellationToken: cancellationToken,
      );
      existing[artifact.modelId] = result;
      if (result.isVerified) verifiedBytes += artifact.byteLength;
    }
    final totalBytes = artifacts.fold<int>(
      0,
      (total, artifact) => total + artifact.byteLength,
    );
    final missingBytes = totalBytes - verifiedBytes;
    onProgress(
      ModelInstallProgress(
        stage: ModelInstallStage.checkingStorage,
        completedBytes: verifiedBytes,
        totalBytes: totalBytes,
      ),
    );
    final available = await storageProbe.availableBytes(
      layout.rootDirectory.path,
    );
    if (available != null && available < missingBytes + freeSpaceReserveBytes) {
      throw AiRuntimeException(
        code: AiErrorCode.insufficientStorage,
        stage: 'model-install',
        message:
            'Offline AI needs ${missingBytes + freeSpaceReserveBytes} free bytes; only $available are available.',
      );
    }

    var completedBytes = verifiedBytes;
    for (final artifact in artifacts) {
      if (existing[artifact.modelId]?.isVerified ?? false) continue;
      cancellationToken?.throwIfCancelled();
      final target = File(layout.pathFor(artifact));
      await target.parent.create(recursive: true);
      final temporary = File('${target.path}.part');
      final backup = File('${target.path}.previous');
      await _deleteIfExists(temporary);
      await _deleteIfExists(backup);
      try {
        await transfer.download(
          artifact: artifact,
          destination: temporary,
          cancellationToken: cancellationToken,
          onProgress: (receivedBytes) => onProgress(
            ModelInstallProgress(
              stage: ModelInstallStage.downloading,
              completedBytes: completedBytes + receivedBytes,
              totalBytes: totalBytes,
              artifact: artifact,
            ),
          ),
        );
        cancellationToken?.throwIfCancelled();
        onProgress(
          ModelInstallProgress(
            stage: ModelInstallStage.verifying,
            completedBytes: completedBytes,
            totalBytes: totalBytes,
            artifact: artifact,
          ),
        );
        final verification = await verifier.verify(
          artifact: artifact,
          path: temporary.path,
          cancellationToken: cancellationToken,
        );
        if (!verification.isVerified) {
          throw AiRuntimeException(
            code: AiErrorCode.modelVerificationFailed,
            stage: 'model-verify',
            message:
                'SHA-256 verification failed for ${artifact.modelId}; the file was not activated.',
          );
        }
        onProgress(
          ModelInstallProgress(
            stage: ModelInstallStage.activating,
            completedBytes: completedBytes,
            totalBytes: totalBytes,
            artifact: artifact,
          ),
        );
        if (await target.exists()) await target.rename(backup.path);
        try {
          await temporary.rename(target.path);
          await _deleteIfExists(backup);
        } on Object {
          if (!await target.exists() && await backup.exists()) {
            await backup.rename(target.path);
          }
          rethrow;
        }
        completedBytes += artifact.byteLength;
      } finally {
        await _deleteIfExists(temporary);
      }
    }
    await _writeInstallationRecord(schemaVersion, layout, artifacts);
    onProgress(
      ModelInstallProgress(
        stage: ModelInstallStage.completed,
        completedBytes: totalBytes,
        totalBytes: totalBytes,
      ),
    );
  }

  Future<void> removeRequired({
    required Phase7ModelManifest manifest,
    required ModelInstallationLayout layout,
  }) async {
    await removeArtifacts(
      artifacts: requiredPhase7ArtifactIds
          .map(manifest.byId)
          .toList(growable: false),
      layout: layout,
    );
  }

  Future<void> removeArtifacts({
    required List<ModelArtifactManifest> artifacts,
    required ModelInstallationLayout layout,
  }) async {
    for (final artifact in artifacts) {
      final target = File(layout.pathFor(artifact));
      await _deleteIfExists(File('${target.path}.part'));
      await _deleteIfExists(File('${target.path}.previous'));
      await _deleteIfExists(target);
      if (await target.parent.exists() &&
          (await target.parent.list().isEmpty)) {
        await target.parent.delete();
      }
    }
    await _deleteIfExists(
      File('${layout.rootDirectory.path}/installation.json'),
    );
  }

  Future<void> _writeInstallationRecord(
    int schemaVersion,
    ModelInstallationLayout layout,
    List<ModelArtifactManifest> artifacts,
  ) async {
    final target = File('${layout.rootDirectory.path}/installation.json');
    final temporary = File('${target.path}.part');
    await temporary.writeAsString(
      jsonEncode(<String, Object?>{
        'schemaVersion': schemaVersion,
        'installedAt': DateTime.now().toUtc().toIso8601String(),
        'artifacts': artifacts
            .map(
              (artifact) => <String, Object?>{
                'modelId': artifact.modelId,
                'revision': artifact.revision,
                'byteLength': artifact.byteLength,
                'sha256': artifact.sha256,
              },
            )
            .toList(growable: false),
      }),
      flush: true,
    );
    if (await target.exists()) await target.delete();
    await temporary.rename(target.path);
  }

  Future<void> _deleteIfExists(File file) async {
    if (await file.exists()) await file.delete();
  }
}
