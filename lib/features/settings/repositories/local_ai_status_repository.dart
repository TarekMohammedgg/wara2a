import '../../../core/ai/extraction/invoice_text_interpreter.dart';
import '../../../core/ai/extraction/method_channel_qwen_interpreter.dart';
import '../../../core/ai/ai_cancellation_token.dart';
import '../../../core/ai/model_management/bundled_model_manifest.dart';
import '../../../core/ai/model_management/model_capability.dart';
import '../../../core/ai/model_management/model_installation.dart';
import '../../../core/ai/model_management/secure_model_installer.dart';
import '../../../core/ai/ocr/method_channel_ocr_engine.dart';
import '../../../core/ai/ocr/ocr_engine.dart';
import '../models/local_ai_status.dart';

abstract interface class LocalAiStatusRepository {
  Future<LocalAiStatus> inspect();
  Future<void> installRequired(ModelInstallProgressCallback onProgress);
  Future<void> cancelInstallation();
  Future<void> removeRequired();
  Future<void> close();
}

class DeviceLocalAiStatusRepository implements LocalAiStatusRepository {
  DeviceLocalAiStatusRepository({
    OcrEngineFactory? ocrFactory,
    InvoiceTextInterpreterFactory? interpreterFactory,
    this.installationInspector = const ModelInstallationInspector(),
    this.installer = const SecureModelInstaller(),
  }) : ocrFactory = ocrFactory ?? PlatformOcrEngine.new,
       interpreterFactory =
           interpreterFactory ?? PlatformQwenTextInterpreter.new;

  final OcrEngineFactory ocrFactory;
  final InvoiceTextInterpreterFactory interpreterFactory;
  final ModelInstallationInspector installationInspector;
  final SecureModelInstaller installer;
  AiCancellationToken? _installationCancellation;

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
      if (!interpreterCapability.canInitialize) {
        return LocalAiStatus(
          readiness: LocalAiReadiness.runtimeUnavailable,
          ocrCapability: ocrCapability,
          interpreterCapability: interpreterCapability,
        );
      }
      final report = await installationInspector.inspectRequired(
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
          modelFiles: report.files,
        );
      }
      return LocalAiStatus(
        readiness: LocalAiReadiness.ready,
        ocrCapability: ocrCapability,
        interpreterCapability: interpreterCapability,
        modelFiles: report.files,
      );
    } finally {
      await ocr.dispose();
      await interpreter.dispose();
    }
  }

  @override
  Future<void> installRequired(ModelInstallProgressCallback onProgress) async {
    if (_installationCancellation != null) {
      throw StateError('A model installation is already running.');
    }
    final cancellation = AiCancellationToken();
    _installationCancellation = cancellation;
    try {
      final manifest = await loadPhase7ModelManifest();
      final layout = await ModelInstallationLayout.appSupport();
      await installer.installRequired(
        manifest: manifest,
        layout: layout,
        onProgress: onProgress,
        cancellationToken: cancellation,
      );
    } finally {
      if (identical(_installationCancellation, cancellation)) {
        _installationCancellation = null;
      }
    }
  }

  @override
  Future<void> cancelInstallation() async {
    _installationCancellation?.cancel();
  }

  @override
  Future<void> removeRequired() async {
    await cancelInstallation();
    final manifest = await loadPhase7ModelManifest();
    final layout = await ModelInstallationLayout.appSupport();
    await installer.removeRequired(manifest: manifest, layout: layout);
  }

  @override
  Future<void> close() => cancelInstallation();
}
