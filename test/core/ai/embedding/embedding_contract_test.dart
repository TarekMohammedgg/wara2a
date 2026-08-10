import 'dart:ffi';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:wara2a/core/ai/embedding/embedding_engine.dart';
import 'package:wara2a/core/ai/embedding/method_channel_e5_embedding_engine.dart';
import 'package:wara2a/core/ai/embedding/multilingual_e5_artifact.dart';
import 'package:wara2a/core/ai/model_management/model_lifecycle_state.dart';

void main() {
  test('multilingual E5 pins the deployable vector contract', () {
    expect(MultilingualE5Artifact.repository, 'intfloat/multilingual-e5-small');
    expect(
      MultilingualE5Artifact.revision,
      '614241f622f53c4eeff9890bdc4f31cfecc418b3',
    );
    expect(MultilingualE5Artifact.dimensions, 384);
    expect(MultilingualE5Artifact.maximumSequenceTokens, 512);
    expect(MultilingualE5Artifact.embeddingSchemaVersion, 3);
    expect(MultilingualE5Artifact.minimumAndroidApi, 30);
    expect(MultilingualE5Artifact.queryPrefix, 'query: ');
    expect(MultilingualE5Artifact.documentPrefix, 'passage: ');
    expect(MultilingualE5Artifact.modelByteLength, 118346824);
    expect(
      MultilingualE5Artifact.modelSha256,
      'dd476dd0c2514e9b9be83aeb3853fac0763e0bdf4a71645407587d77c48a2d88',
    );
    expect(MultilingualE5Artifact.modelUri.scheme, 'https');
    expect(
      MultilingualE5Artifact.modelUri.path,
      contains(MultilingualE5Artifact.revision),
    );
    expect(MultilingualE5Artifact.license, 'MIT');
    expect(MultilingualE5Artifact.runtimeTuple, contains('1.21.1'));
    expect(MultilingualE5Artifact.runtimeTuple, contains('0.13.0'));
    expect(MultilingualE5Artifact.tokenizerGraphByteLength, 5069598);
    expect(
      MultilingualE5Artifact.tokenizerGraphSha256,
      '9f063c3b86fb5e336b5560b240e49204671bf59766e61ea68bb5462001b5c06b',
    );
    expect(MultilingualE5Artifact.sentencePieceByteLength, 5069051);
    expect(
      MultilingualE5Artifact.sentencePieceSha256,
      'cfc8146abe2a0488e9e2a0c56de7952f7c11ab059eca145a0a727afce0db2865',
    );
    expect(MultilingualE5Artifact.modelManifest.installable, isTrue);
  });

  test('E5 retrieval prefixes are applied exactly once', () {
    expect(
      MultilingualE5Artifact.formatQuery('  milk receipt  '),
      'query: task: search result | query: milk receipt',
    );
    expect(
      MultilingualE5Artifact.formatDocument(
        '  milk receipt body  ',
        title: ' Cairo shop ',
      ),
      'passage: title: Cairo shop | text: milk receipt body',
    );
    expect(
      MultilingualE5Artifact.formatDocument('body'),
      'passage: title: none | text: body',
    );
  });

  test('an engine is usable only when lifecycle and capability are ready', () {
    const ready = EmbeddingEngineSnapshot(
      status: ModelLifecycleStatus.ready,
      capability: EmbeddingCapability.ready,
      modelId: MultilingualE5Artifact.modelId,
    );
    const loading = EmbeddingEngineSnapshot(
      status: ModelLifecycleStatus.loading,
      capability: EmbeddingCapability.ready,
      modelId: MultilingualE5Artifact.modelId,
    );
    const notInstalled = EmbeddingEngineSnapshot(
      status: ModelLifecycleStatus.ready,
      capability: EmbeddingCapability.modelNotInstalled,
      modelId: MultilingualE5Artifact.modelId,
    );

    expect(ready.canEmbed, isTrue);
    expect(loading.canEmbed, isFalse);
    expect(notInstalled.canEmbed, isFalse);
  });

  test('native support is truthfully gated to Android arm64', () {
    final expected = Platform.isAndroid && Abi.current() == Abi.androidArm64;
    expect(MethodChannelE5EmbeddingEngine.supportsCurrentPlatform, expected);
  });

  test('unavailable engine exposes a truthful capability gate', () async {
    final engine = UnavailableEmbeddingEngine(
      modelId: MultilingualE5Artifact.modelId,
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
