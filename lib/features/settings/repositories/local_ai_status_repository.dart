import '../../../core/ai/extraction/invoice_text_interpreter.dart';
import '../../../core/ai/model_management/bundled_model_manifest.dart';
import '../../../core/ai/model_management/model_capability.dart';
import '../../../core/ai/model_management/model_installation.dart';
import '../../../core/ai/ocr/method_channel_ocr_engine.dart';
import '../../../core/ai/ocr/ocr_engine.dart';
import '../models/local_ai_status.dart';

abstract interface class LocalAiStatusRepository {
  Future<LocalAiStatus> inspect();
}

class DeviceLocalAiStatusRepository implements LocalAiStatusRepository {
  DeviceLocalAiStatusRepository({
    OcrEngineFactory? ocrFactory,
    InvoiceTextInterpreterFactory? interpreterFactory,
    this.installationInspector = const ModelInstallationInspector(),
  }) : ocrFactory = ocrFactory ?? PlatformOcrEngine.new,
       interpreterFactory =
           interpreterFactory ?? IncompatibleQwenLiteRtInterpreter.new;

  final OcrEngineFactory ocrFactory;
  final InvoiceTextInterpreterFactory interpreterFactory;
  final ModelInstallationInspector installationInspector;

  @override
  Future<LocalAiStatus> inspect() async {
    final ocr = ocrFactory();
    final interpreter = interpreterFactory();
    try {
      final capabilities = await Future.wait<ModelCapability>(
        <Future<ModelCapability>>[ocr.capability(), interpreter.capability()],
      );
      final ocrCapability = capabilities[0];
      final interpreterCapability = capabilities[1];
      if (ocrCapability.status == ModelCapabilityStatus.unsupportedPlatform) {
        return LocalAiStatus(
          readiness: LocalAiReadiness.unsupportedPlatform,
          ocrCapability: ocrCapability,
          interpreterCapability: interpreterCapability,
        );
      }
      if (!ocrCapability.canInitialize) {
        return LocalAiStatus(
          readiness: LocalAiReadiness.runtimeUnavailable,
          ocrCapability: ocrCapability,
          interpreterCapability: interpreterCapability,
        );
      }
      final manifest = await loadPhase7ModelManifest();
      final layout = await ModelInstallationLayout.appSupport();
      final report = await installationInspector.inspectOcr(
        manifest: manifest,
        layout: layout,
      );
      if (!report.isReady) {
        return LocalAiStatus(
          readiness: report.hasCorruptFile
              ? LocalAiReadiness.modelVerificationFailed
              : LocalAiReadiness.modelsNotInstalled,
          ocrCapability: ocrCapability,
          interpreterCapability: interpreterCapability,
          ocrFiles: report.files,
        );
      }
      if (!interpreterCapability.canInitialize) {
        return LocalAiStatus(
          readiness: LocalAiReadiness.interpreterArtifactIncompatible,
          ocrCapability: ocrCapability,
          interpreterCapability: interpreterCapability,
          ocrFiles: report.files,
        );
      }
      return LocalAiStatus(
        readiness: LocalAiReadiness.ready,
        ocrCapability: ocrCapability,
        interpreterCapability: interpreterCapability,
        ocrFiles: report.files,
      );
    } finally {
      await ocr.dispose();
      await interpreter.dispose();
    }
  }
}
