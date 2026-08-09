import '../../../core/ai/model_management/model_capability.dart';
import '../../../core/ai/model_management/model_file_verifier.dart';

enum LocalAiReadiness {
  unsupportedPlatform,
  runtimeUnavailable,
  modelsNotInstalled,
  modelVerificationFailed,
  interpreterArtifactIncompatible,
  ready,
}

class LocalAiStatus {
  const LocalAiStatus({
    required this.readiness,
    required this.ocrCapability,
    required this.interpreterCapability,
    this.modelFiles = const <ModelFileVerification>[],
  });

  final LocalAiReadiness readiness;
  final ModelCapability ocrCapability;
  final ModelCapability interpreterCapability;
  final List<ModelFileVerification> modelFiles;

  List<ModelFileVerification> get ocrFiles => modelFiles
      .where(
        (file) =>
            file.artifact.capabilities.any((value) => value.startsWith('ocr-')),
      )
      .toList(growable: false);

  int get installedBytes => modelFiles
      .where((file) => file.isVerified)
      .fold<int>(0, (total, file) => total + (file.actualByteLength ?? 0));

  int get requiredBytes => modelFiles.fold<int>(
    0,
    (total, file) => total + file.artifact.byteLength,
  );
}
