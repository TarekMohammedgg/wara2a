import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wara2a/core/ai/embedding/method_channel_e5_embedding_engine.dart';
import 'package:wara2a/core/ai/embedding/multilingual_e5_artifact.dart';
import 'package:wara2a/core/ai/model_management/model_file_verifier.dart';
import 'package:wara2a/core/ai/model_management/model_installation.dart';
import 'package:wara2a/core/ai/model_management/model_manifest.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'loads, prefixes, validates, unloads, and reloads the native model',
    () async {
      final directory = await Directory.systemTemp.createTemp('wara2a_e5_');
      final channel = MethodChannel(
        'com.wara2a.ai/embedding.test.${directory.path.hashCode}',
      );
      final calls = <MethodCall>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return switch (call.method) {
          'initialize' => <String, Object?>{
            'dimensions': MultilingualE5Artifact.dimensions,
            'modelId': MultilingualE5Artifact.modelId,
            'runtime': MultilingualE5Artifact.runtimeTuple,
            'tokenizerBytes': MultilingualE5Artifact.tokenizerGraphByteLength,
            'tokenizerSha256': MultilingualE5Artifact.tokenizerGraphSha256,
          },
          'embed' => <String, Object?>{
            'embedding': List<double>.generate(
              MultilingualE5Artifact.dimensions,
              (index) => index == 0 ? 3 : (index == 1 ? 4 : 0),
            ),
            'dimensions': MultilingualE5Artifact.dimensions,
          'modelId': MultilingualE5Artifact.modelId,
          'tokenizerBytes': MultilingualE5Artifact.tokenizerGraphByteLength,
          'tokenizerSha256': MultilingualE5Artifact.tokenizerGraphSha256,
            'elapsedMs': 7,
            'runtime': MultilingualE5Artifact.runtimeTuple,
          },
          'cancel' || 'unload' || 'dispose' => null,
          _ => throw PlatformException(code: 'unexpected_method'),
        };
      });
      addTearDown(() async {
        messenger.setMockMethodCallHandler(channel, null);
        if (await directory.exists()) await directory.delete(recursive: true);
      });

      final engine = MethodChannelE5EmbeddingEngine(
        layout: ModelInstallationLayout(directory),
        channel: channel,
        inspector: const _ReadyInspector(),
        platformSupported: true,
      );

      expect((await engine.refresh()).canEmbed, isTrue);
      final document = await engine.embedDocument(
        '  milk receipt body  ',
        title: ' Cairo shop ',
      );
      final query = await engine.embedQuery('  milk receipt  ');

      expect(document.vector, hasLength(384));
      expect(document.vector[0], closeTo(0.6, 1e-12));
      expect(document.vector[1], closeTo(0.8, 1e-12));
      expect(query.modelId, MultilingualE5Artifact.modelId);
      final embeddedTexts = calls
          .where((call) => call.method == 'embed')
          .map((call) => (call.arguments as Map<Object?, Object?>)['text'])
          .toList(growable: false);
      expect(embeddedTexts, <String>[
        'passage: title: Cairo shop | text: milk receipt body',
        'query: task: search result | query: milk receipt',
      ]);

      await engine.unload();
      expect(engine.snapshot.canEmbed, isTrue);
      await engine.embedQuery('receipt');
      expect(calls.where((call) => call.method == 'initialize'), hasLength(2));
      await engine.cancel();
      await engine.dispose();
      expect(calls.any((call) => call.method == 'dispose'), isTrue);
    },
  );

  test(
    'rejects an incompatible native dimension before becoming ready',
    () async {
      final directory = await Directory.systemTemp.createTemp('wara2a_e5_bad_');
      final channel = MethodChannel(
        'com.wara2a.ai/embedding.bad.${directory.path.hashCode}',
      );
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'initialize') {
          return <String, Object?>{
            'dimensions': 768,
            'modelId': MultilingualE5Artifact.modelId,
          };
        }
        return null;
      });
      addTearDown(() async {
        messenger.setMockMethodCallHandler(channel, null);
        if (await directory.exists()) await directory.delete(recursive: true);
      });
      final engine = MethodChannelE5EmbeddingEngine(
        layout: ModelInstallationLayout(directory),
        channel: channel,
        inspector: const _ReadyInspector(),
        platformSupported: true,
      );

      final snapshot = await engine.refresh();
      expect(snapshot.canEmbed, isFalse);
      expect(snapshot.message, contains('incompatible model contract'));
      await engine.dispose();
    },
  );
}

class _ReadyInspector extends ModelInstallationInspector {
  const _ReadyInspector();

  @override
  Future<ModelInstallationReport> inspectArtifacts({
    required List<ModelArtifactManifest> artifacts,
    required ModelInstallationLayout layout,
    cancellationToken,
  }) async {
    return ModelInstallationReport(
      artifacts
          .map(
            (artifact) => ModelFileVerification(
              artifact: artifact,
              path: layout.pathFor(artifact),
              status: ModelFileVerificationStatus.verified,
              actualByteLength: artifact.byteLength,
              actualSha256: artifact.sha256,
            ),
          )
          .toList(growable: false),
    );
  }
}
