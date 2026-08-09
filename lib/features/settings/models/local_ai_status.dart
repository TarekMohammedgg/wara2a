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
    this.ocrFiles = const <ModelFileVerification>[],
  });

  final LocalAiReadiness readiness;
  final ModelCapability ocrCapability;
  final ModelCapability interpreterCapability;
  final List<ModelFileVerification> ocrFiles;

  int get installedOcrBytes => ocrFiles
      .where((file) => file.isVerified)
      .fold<int>(0, (total, file) => total + (file.actualByteLength ?? 0));
}
