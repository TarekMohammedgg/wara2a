import '../embedding/multilingual_e5_artifact.dart';
import 'model_installation.dart';

/// Single offline-AI install contract shown and downloaded by Settings.
abstract final class OfflineAiBundle {
  static const extractionDisplayName =
      'PP-OCRv5 mobile + Qwen2.5-0.5B-Instruct Q8';
  static const embeddingDisplayName = 'multilingual-e5-small qint8';

  /// Sum of the seven Phase 7 artifacts in `phase7_model_manifest.json`.
  static const extractionByteLength = 567541717;

  static const embeddingByteLength = MultilingualE5Artifact.modelByteLength;

  static const totalByteLength = extractionByteLength + embeddingByteLength;

  static const totalMebibytesLabel = '654.1';

  static const totalBytesLabel = '685,888,541';

  static List<String> get requiredExtractionArtifactIds =>
      requiredPhase7ArtifactIds;

  static final embeddingArtifact = MultilingualE5Artifact.modelManifest;
}
