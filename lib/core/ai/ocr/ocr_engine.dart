import '../ai_cancellation_token.dart';
import '../model_management/model_capability.dart';
import 'ocr_evidence.dart';

class OcrModelFiles {
  const OcrModelFiles({
    required this.detectorModelPath,
    required this.detectorConfigPath,
    required this.arabicModelPath,
    required this.arabicConfigPath,
    required this.latinModelPath,
    required this.latinConfigPath,
  });

  final String detectorModelPath;
  final String detectorConfigPath;
  final String arabicModelPath;
  final String arabicConfigPath;
  final String latinModelPath;
  final String latinConfigPath;

  Map<String, Object?> toMap() => <String, Object?>{
    'detectorModelPath': detectorModelPath,
    'detectorConfigPath': detectorConfigPath,
    'arabicModelPath': arabicModelPath,
    'arabicConfigPath': arabicConfigPath,
    'latinModelPath': latinModelPath,
    'latinConfigPath': latinConfigPath,
  };
}

abstract interface class OcrEngine {
  Future<ModelCapability> capability();

  Future<void> initialize(
    OcrModelFiles models, {
    AiCancellationToken? cancellationToken,
  });

  Future<OcrEvidence> recognizeInvoice(
    String imagePath, {
    AiCancellationToken? cancellationToken,
  });

  Future<void> cancel();
  Future<void> dispose();
}

typedef OcrEngineFactory = OcrEngine Function();
