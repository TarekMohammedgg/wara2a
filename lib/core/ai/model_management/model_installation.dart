import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../ai_cancellation_token.dart';
import '../ocr/ocr_engine.dart';
import 'model_file_verifier.dart';
import 'model_manifest.dart';

class ModelInstallationLayout {
  const ModelInstallationLayout(this.rootDirectory);

  final Directory rootDirectory;

  static Future<ModelInstallationLayout> appSupport() async {
    final support = await getApplicationSupportDirectory();
    return ModelInstallationLayout(Directory('${support.path}/models/phase7'));
  }

  String pathFor(ModelArtifactManifest artifact) =>
      '${rootDirectory.path}/${artifact.modelId}/${artifact.fileName}';

  OcrModelFiles ocrFiles(Phase7ModelManifest manifest) {
    return OcrModelFiles(
      detectorModelPath: pathFor(manifest.byId('ppocrv5-mobile-det-onnx')),
      detectorConfigPath: pathFor(manifest.byId('ppocrv5-mobile-det-yaml')),
      arabicModelPath: pathFor(manifest.byId('ppocrv5-mobile-rec-arabic-onnx')),
      arabicConfigPath: pathFor(
        manifest.byId('ppocrv5-mobile-rec-arabic-yaml'),
      ),
      latinModelPath: pathFor(manifest.byId('ppocrv5-mobile-rec-latin-onnx')),
      latinConfigPath: pathFor(manifest.byId('ppocrv5-mobile-rec-latin-yaml')),
    );
  }

  String qwenModelPath(Phase7ModelManifest manifest) =>
      pathFor(manifest.byId('qwen2.5-0.5b-instruct-q8-task'));
}

class ModelInstallationReport {
  const ModelInstallationReport(this.files);

  final List<ModelFileVerification> files;

  bool get isReady =>
      files.isNotEmpty && files.every((file) => file.isVerified);
  bool get hasCorruptFile => files.any(
    (file) =>
        file.status == ModelFileVerificationStatus.wrongLength ||
        file.status == ModelFileVerificationStatus.checksumMismatch,
  );
}

class ModelInstallationInspector {
  const ModelInstallationInspector({this.verifier = const ModelFileVerifier()});

  final ModelFileVerifier verifier;

  Future<ModelInstallationReport> inspectRequired({
    required Phase7ModelManifest manifest,
    required ModelInstallationLayout layout,
    AiCancellationToken? cancellationToken,
  }) async {
    const ids = requiredPhase7ArtifactIds;
    final results = <ModelFileVerification>[];
    for (final id in ids) {
      cancellationToken?.throwIfCancelled();
      final artifact = manifest.byId(id);
      results.add(
        await verifier.verify(
          artifact: artifact,
          path: layout.pathFor(artifact),
          cancellationToken: cancellationToken,
        ),
      );
    }
    return ModelInstallationReport(List.unmodifiable(results));
  }

  Future<ModelInstallationReport> inspectOcr({
    required Phase7ModelManifest manifest,
    required ModelInstallationLayout layout,
    AiCancellationToken? cancellationToken,
  }) async {
    const ids = <String>[
      'ppocrv5-mobile-det-onnx',
      'ppocrv5-mobile-det-yaml',
      'ppocrv5-mobile-rec-arabic-onnx',
      'ppocrv5-mobile-rec-arabic-yaml',
      'ppocrv5-mobile-rec-latin-onnx',
      'ppocrv5-mobile-rec-latin-yaml',
    ];
    final results = <ModelFileVerification>[];
    for (final id in ids) {
      cancellationToken?.throwIfCancelled();
      final artifact = manifest.byId(id);
      results.add(
        await verifier.verify(
          artifact: artifact,
          path: layout.pathFor(artifact),
          cancellationToken: cancellationToken,
        ),
      );
    }
    return ModelInstallationReport(List.unmodifiable(results));
  }
}

const List<String> requiredPhase7ArtifactIds = <String>[
  'ppocrv5-mobile-det-onnx',
  'ppocrv5-mobile-det-yaml',
  'ppocrv5-mobile-rec-arabic-onnx',
  'ppocrv5-mobile-rec-arabic-yaml',
  'ppocrv5-mobile-rec-latin-onnx',
  'ppocrv5-mobile-rec-latin-yaml',
  'qwen2.5-0.5b-instruct-q8-task',
];
