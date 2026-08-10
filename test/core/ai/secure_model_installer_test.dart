import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wara2a/core/ai/ai_runtime_error.dart';
import 'package:wara2a/core/ai/model_management/model_installation.dart';
import 'package:wara2a/core/ai/model_management/model_manifest.dart';
import 'package:wara2a/core/ai/model_management/secure_model_installer.dart';

void main() {
  test(
    'downloads, verifies, and atomically activates the exact model set',
    () async {
      final fixture = _manifestFixture();
      final directory = await Directory.systemTemp.createTemp(
        'wara2a_secure_installer_',
      );
      addTearDown(() => directory.delete(recursive: true));
      final layout = ModelInstallationLayout(directory);
      final progress = <ModelInstallProgress>[];

      await SecureModelInstaller(
        transfer: _FixtureTransfer(fixture.payloads),
        storageProbe: const _StorageProbe(1 << 30),
        freeSpaceReserveBytes: 0,
      ).installRequired(
        manifest: fixture.manifest,
        layout: layout,
        onProgress: progress.add,
      );

      for (final artifact in fixture.manifest.artifacts) {
        expect(
          await File(layout.pathFor(artifact)).readAsBytes(),
          fixture.payloads[artifact.modelId],
        );
        expect(File('${layout.pathFor(artifact)}.part').existsSync(), isFalse);
      }
      final record =
          jsonDecode(
                await File(
                  '${directory.path}/installation.json',
                ).readAsString(),
              )
              as Map<String, Object?>;
      expect(record['schemaVersion'], 2);
      expect(
        record['artifacts'],
        isA<List<Object?>>().having(
          (entries) => entries.length,
          'length',
          requiredPhase7ArtifactIds.length,
        ),
      );
      expect(progress.last.stage, ModelInstallStage.completed);
      expect(progress.last.completedBytes, progress.last.totalBytes);
    },
  );

  test('never activates an artifact whose SHA-256 does not match', () async {
    final fixture = _manifestFixture();
    final directory = await Directory.systemTemp.createTemp(
      'wara2a_corrupt_installer_',
    );
    addTearDown(() => directory.delete(recursive: true));
    final layout = ModelInstallationLayout(directory);
    final corruptId = requiredPhase7ArtifactIds.last;

    await expectLater(
      SecureModelInstaller(
        transfer: _FixtureTransfer(fixture.payloads, corruptId: corruptId),
        storageProbe: const _StorageProbe(1 << 30),
        freeSpaceReserveBytes: 0,
      ).installRequired(
        manifest: fixture.manifest,
        layout: layout,
        onProgress: (_) {},
      ),
      throwsA(
        isA<AiRuntimeException>().having(
          (error) => error.code,
          'code',
          AiErrorCode.modelVerificationFailed,
        ),
      ),
    );

    final artifact = fixture.manifest.byId(corruptId);
    expect(File(layout.pathFor(artifact)).existsSync(), isFalse);
    expect(File('${layout.pathFor(artifact)}.part').existsSync(), isFalse);
    expect(File('${directory.path}/installation.json').existsSync(), isFalse);
  });

  test('installs an explicit embedding artifact set without Phase 7 coupling',
      () async {
    final fixture = _manifestFixture();
    final artifact = fixture.manifest.artifacts.first;
    final directory = await Directory.systemTemp.createTemp(
      'wara2a_embedding_installer_',
    );
    addTearDown(() => directory.delete(recursive: true));
    final layout = ModelInstallationLayout(directory);

    await SecureModelInstaller(
      transfer: _FixtureTransfer(fixture.payloads),
      storageProbe: const _StorageProbe(1 << 30),
      freeSpaceReserveBytes: 0,
    ).installArtifacts(
      artifacts: <ModelArtifactManifest>[artifact],
      schemaVersion: 3,
      layout: layout,
      onProgress: (_) {},
    );

    expect(await File(layout.pathFor(artifact)).exists(), isTrue);
    final record = jsonDecode(
      await File('${directory.path}/installation.json').readAsString(),
    ) as Map<String, Object?>;
    expect(record['schemaVersion'], 3);
    expect((record['artifacts'] as List<Object?>), hasLength(1));
  });

  test('accepts Hugging Face relative HTTPS resolve-cache redirects', () {
    final origin = Uri.parse(
      'https://huggingface.co/PaddlePaddle/PP-OCRv5_mobile_det_onnx/'
      'resolve/e6f4fa85/inference.yml',
    );
    final redirects = <RedirectInfo>[
      _RedirectInfo(
        statusCode: HttpStatus.temporaryRedirect,
        method: 'GET',
        location: Uri.parse(
          '/api/resolve-cache/models/PaddlePaddle/PP-OCRv5_mobile_det_onnx/'
          'e6f4fa85/inference.yml',
        ),
      ),
    ];

    expect(
      HttpsModelArtifactTransfer.redirectsStayOnHttps(origin, redirects),
      isTrue,
    );
  });

  test('rejects a redirect chain that leaves HTTPS', () {
    final origin = Uri.parse('https://huggingface.co/example/resolve/main/a.bin');
    final redirects = <RedirectInfo>[
      _RedirectInfo(
        statusCode: HttpStatus.found,
        method: 'GET',
        location: Uri.parse('http://cdn.example.test/a.bin'),
      ),
    ];

    expect(
      HttpsModelArtifactTransfer.redirectsStayOnHttps(origin, redirects),
      isFalse,
    );
  });
}

class _RedirectInfo implements RedirectInfo {
  _RedirectInfo({
    required this.statusCode,
    required this.method,
    required this.location,
  });

  @override
  final int statusCode;

  @override
  final String method;

  @override
  final Uri location;
}

class _ManifestFixture {
  const _ManifestFixture(this.manifest, this.payloads);

  final Phase7ModelManifest manifest;
  final Map<String, List<int>> payloads;
}

_ManifestFixture _manifestFixture() {
  final payloads = <String, List<int>>{};
  final artifacts = requiredPhase7ArtifactIds
      .map((id) {
        final payload = utf8.encode('verified fixture for $id');
        payloads[id] = payload;
        return ModelArtifactManifest(
          modelId: id,
          displayName: id,
          runtime: 'fixture',
          fileName: id.endsWith('-task') ? 'model.task' : 'model.bin',
          revision: 'fixture-revision',
          byteLength: payload.length,
          sha256: sha256.convert(payload).toString(),
          minimumAppVersion: '1.0.0',
          capabilities: const <String>['test'],
          format: id.endsWith('-task')
              ? ModelArtifactFormat.mediaPipeTask
              : ModelArtifactFormat.onnx,
          sourceUri: Uri.parse('https://example.test/$id'),
          license: 'Apache-2.0',
          installable: true,
        );
      })
      .toList(growable: false);
  return _ManifestFixture(
    Phase7ModelManifest(
      schemaVersion: 2,
      researchedAt: DateTime.utc(2026, 8, 9),
      artifacts: artifacts,
    ),
    payloads,
  );
}

class _FixtureTransfer implements ModelArtifactTransfer {
  const _FixtureTransfer(this.payloads, {this.corruptId});

  final Map<String, List<int>> payloads;
  final String? corruptId;

  @override
  Future<void> download({
    required ModelArtifactManifest artifact,
    required File destination,
    required void Function(int receivedBytes) onProgress,
    cancellationToken,
  }) async {
    cancellationToken?.throwIfCancelled();
    final expected = payloads[artifact.modelId]!;
    final payload = artifact.modelId == corruptId
        ? <int>[expected.first ^ 0xff, ...expected.skip(1)]
        : expected;
    await destination.writeAsBytes(payload, flush: true);
    onProgress(payload.length);
  }
}

class _StorageProbe implements ModelStorageProbe {
  const _StorageProbe(this.bytes);

  final int bytes;

  @override
  Future<int?> availableBytes(String path) async => bytes;
}
