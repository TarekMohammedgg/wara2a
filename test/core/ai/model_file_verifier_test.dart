import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:wara2a/core/ai/model_management/model_file_verifier.dart';
import 'package:wara2a/core/ai/model_management/model_manifest.dart';

void main() {
  late Directory temporaryDirectory;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'wara2a_model_verifier_',
    );
  });

  tearDown(() async {
    if (await temporaryDirectory.exists()) {
      await temporaryDirectory.delete(recursive: true);
    }
  });

  test('verifies the exact byte length and SHA-256 digest', () async {
    final path = '${temporaryDirectory.path}/model.onnx';
    await File(path).writeAsBytes(<int>[97, 98, 99]);

    final result = await const ModelFileVerifier().verify(
      artifact: _artifact(),
      path: path,
    );

    expect(result.status, ModelFileVerificationStatus.verified);
    expect(result.actualByteLength, 3);
    expect(
      result.actualSha256,
      'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
    );
  });

  test('distinguishes missing, wrong-length, and corrupt files', () async {
    final verifier = const ModelFileVerifier();
    final missingPath = '${temporaryDirectory.path}/missing.onnx';
    expect(
      (await verifier.verify(artifact: _artifact(), path: missingPath)).status,
      ModelFileVerificationStatus.missing,
    );

    final wrongLengthPath = '${temporaryDirectory.path}/short.onnx';
    await File(wrongLengthPath).writeAsBytes(<int>[97, 98]);
    expect(
      (await verifier.verify(
        artifact: _artifact(),
        path: wrongLengthPath,
      )).status,
      ModelFileVerificationStatus.wrongLength,
    );

    final corruptPath = '${temporaryDirectory.path}/corrupt.onnx';
    await File(corruptPath).writeAsBytes(<int>[97, 98, 100]);
    expect(
      (await verifier.verify(artifact: _artifact(), path: corruptPath)).status,
      ModelFileVerificationStatus.checksumMismatch,
    );
  });
}

ModelArtifactManifest _artifact() => ModelArtifactManifest(
  modelId: 'test-model',
  displayName: 'Test model',
  runtime: 'test',
  fileName: 'model.onnx',
  revision: 'test-revision',
  byteLength: 3,
  sha256: 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
  minimumAppVersion: '1.0.0',
  capabilities: const <String>['test'],
  format: ModelArtifactFormat.onnx,
  sourceUri: Uri.parse('https://example.invalid/model.onnx'),
  license: 'Apache-2.0',
  installable: true,
);
