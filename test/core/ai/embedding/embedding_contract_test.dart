import 'dart:ffi';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:wara2a/core/ai/embedding/embedding_engine.dart';
import 'package:wara2a/core/ai/embedding/embedding_gemma_artifact.dart';
import 'package:wara2a/core/ai/embedding/flutter_gemma_embedding_engine.dart';
import 'package:wara2a/core/ai/model_management/model_lifecycle_state.dart';

void main() {
  test('EmbeddingGemma artifact pins the persisted vector contract', () {
    expect(EmbeddingGemmaArtifact.dimensions, 768);
    expect(EmbeddingGemmaArtifact.maximumSequenceTokens, 256);
    expect(EmbeddingGemmaArtifact.embeddingSchemaVersion, 2);
    expect(EmbeddingGemmaArtifact.minimumAndroidApi, 30);
    expect(
      EmbeddingGemmaArtifact.modelFileName,
      'embeddinggemma-300M_seq256_mixed-precision.tflite',
    );
    expect(EmbeddingGemmaArtifact.tokenizerFileName, 'sentencepiece.model');
    expect(EmbeddingGemmaArtifact.modelByteLength, 179131736);
    expect(EmbeddingGemmaArtifact.tokenizerByteLength, 4683319);
    expect(
      EmbeddingGemmaArtifact.modelSha256,
      '37115ef7bff76cd37dd86abe503ff511b1032bf85fc624a85c49c84899e92bc5',
    );
    expect(
      EmbeddingGemmaArtifact.tokenizerSha256,
      'd6daa52d93d7aad10e8388bd526c4e501d914b47177398d1d9621f1fe48438c7',
    );
    expect(
      EmbeddingGemmaArtifact.modelUrl,
      endsWith('/${EmbeddingGemmaArtifact.modelFileName}'),
    );
    expect(
      EmbeddingGemmaArtifact.tokenizerUrl,
      endsWith('/${EmbeddingGemmaArtifact.tokenizerFileName}'),
    );
    expect(EmbeddingGemmaArtifact.runtimeTuple, contains('LiteRT-LM 0.14.0'));
    expect(
      EmbeddingGemmaArtifact.modelId,
      allOf(
        contains(EmbeddingGemmaArtifact.modelSha256),
        contains(EmbeddingGemmaArtifact.tokenizerSha256),
        contains('litertlm-0.14.0'),
        contains(EmbeddingGemmaArtifact.promptContract),
        contains('schema-${EmbeddingGemmaArtifact.embeddingSchemaVersion}'),
      ),
    );
    expect(EmbeddingGemmaArtifact.requiresAcceptedLicenseAndToken, isTrue);
  });

  test('an engine is usable only when lifecycle and capability are ready', () {
    const ready = EmbeddingEngineSnapshot(
      status: ModelLifecycleStatus.ready,
      capability: EmbeddingCapability.ready,
      modelId: EmbeddingGemmaArtifact.modelId,
    );
    const loading = EmbeddingEngineSnapshot(
      status: ModelLifecycleStatus.loading,
      capability: EmbeddingCapability.ready,
      modelId: EmbeddingGemmaArtifact.modelId,
    );
    const notInstalled = EmbeddingEngineSnapshot(
      status: ModelLifecycleStatus.ready,
      capability: EmbeddingCapability.modelNotInstalled,
      modelId: EmbeddingGemmaArtifact.modelId,
    );

    expect(ready.canEmbed, isTrue);
    expect(loading.canEmbed, isFalse);
    expect(notInstalled.canEmbed, isFalse);
  });

  test('native support uses ABI constants instead of ABI display text', () {
    final abi = Abi.current();
    final expected =
        (Platform.isAndroid && abi == Abi.androidArm64) ||
        (Platform.isIOS && abi == Abi.iosArm64) ||
        (Platform.isWindows && abi == Abi.windowsX64) ||
        (Platform.isMacOS && abi == Abi.macosArm64) ||
        (Platform.isLinux &&
            (abi == Abi.linuxX64 || abi == Abi.linuxArm64));

    expect(FlutterGemmaEmbeddingEngine.supportsCurrentPlatform, expected);
  });

  test('unavailable engine exposes a truthful capability gate', () async {
    final engine = UnavailableEmbeddingEngine(
      modelId: EmbeddingGemmaArtifact.modelId,
      reason: 'contract fixture: runtime unavailable',
    );

    expect(engine.snapshot.canEmbed, isFalse);
    expect(engine.snapshot.capability, EmbeddingCapability.unsupportedPlatform);
    expect(await engine.snapshots.first, same(engine.snapshot));
    await expectLater(
      engine.embedDocument('reviewed invoice'),
      throwsA(isA<EmbeddingUnavailableException>()),
    );
    await expectLater(
      engine.embedQuery('invoice query'),
      throwsA(isA<EmbeddingUnavailableException>()),
    );
    await expectLater(
      engine.install(),
      throwsA(isA<EmbeddingUnavailableException>()),
    );
    await engine.unload();
    await engine.cancel();
    await engine.dispose();
  });
}
