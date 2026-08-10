import '../../../core/ai/ai_cancellation_token.dart';
import '../../../core/ai/embedding/embedding_engine.dart';
import '../../../core/ai/embedding/multilingual_e5_artifact.dart';
import '../../../core/ai/extraction/invoice_text_interpreter.dart';
import '../../../core/ai/extraction/method_channel_qwen_interpreter.dart';
import '../../../core/ai/model_management/bundled_model_manifest.dart';
import '../../../core/ai/model_management/model_capability.dart';
import '../../../core/ai/model_management/model_file_verifier.dart';
import '../../../core/ai/model_management/model_installation.dart';
import '../../../core/ai/model_management/model_manifest.dart';
import '../../../core/ai/model_management/offline_ai_bundle.dart';
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
    this.embeddingEngine,
    this.installationInspector = const ModelInstallationInspector(),
    this.installer = const SecureModelInstaller(),
  }) : ocrFactory = ocrFactory ?? PlatformOcrEngine.new,
       interpreterFactory =
           interpreterFactory ?? PlatformQwenTextInterpreter.new;

  final OcrEngineFactory ocrFactory;
  final InvoiceTextInterpreterFactory interpreterFactory;
  final EmbeddingEngine? embeddingEngine;
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
      final embeddingReport = await _inspectEmbedding();
      final files = <ModelFileVerification>[
        ...report.files,
        if (embeddingReport != null) ...embeddingReport.files,
      ];
      final embeddingReady = !_includesEmbedding
          ? true
          : (embeddingReport?.isReady ?? false);
      if (!report.isReady || !embeddingReady) {
        final corrupt =
            report.hasCorruptFile ||
            (embeddingReport?.hasCorruptFile ?? false);
        return LocalAiStatus(
          readiness: corrupt
              ? LocalAiReadiness.modelVerificationFailed
              : LocalAiReadiness.modelsNotInstalled,
          ocrCapability: ocrCapability,
          interpreterCapability: interpreterCapability,
          modelFiles: files,
          embeddingReady: embeddingReady,
        );
      }
      return LocalAiStatus(
        readiness: LocalAiReadiness.ready,
        ocrCapability: ocrCapability,
        interpreterCapability: interpreterCapability,
        modelFiles: files,
        embeddingReady: embeddingReady,
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
      final extractionLayout = await ModelInstallationLayout.appSupport();
      final embeddingLayout = await ModelInstallationLayout.embeddingV3();
      final extractionArtifacts = OfflineAiBundle.requiredExtractionArtifactIds
          .map(manifest.byId)
          .toList(growable: false);
      final embeddingArtifacts = <ModelArtifactManifest>[
        OfflineAiBundle.embeddingArtifact,
      ];

      void reportCombined({
        required int extractionCompleted,
        required int embeddingCompleted,
        required ModelInstallStage stage,
        ModelArtifactManifest? artifact,
      }) {
        final totalBytes = OfflineAiBundle.extractionByteLength +
            (_includesEmbedding ? OfflineAiBundle.embeddingByteLength : 0);
        onProgress(
          ModelInstallProgress(
            stage: stage,
            completedBytes: extractionCompleted + embeddingCompleted,
            totalBytes: totalBytes,
            artifact: artifact,
          ),
        );
      }

      await installer.installArtifacts(
        artifacts: extractionArtifacts,
        schemaVersion: manifest.schemaVersion,
        layout: extractionLayout,
        cancellationToken: cancellation,
        onProgress: (progress) {
          reportCombined(
            extractionCompleted: progress.completedBytes,
            embeddingCompleted: 0,
            stage: progress.stage,
            artifact: progress.artifact,
          );
        },
      );
      cancellation.throwIfCancelled();

      if (_includesEmbedding) {
        await installer.installArtifacts(
          artifacts: embeddingArtifacts,
          schemaVersion: MultilingualE5Artifact.embeddingSchemaVersion,
          layout: embeddingLayout,
          cancellationToken: cancellation,
          onProgress: (progress) {
            reportCombined(
              extractionCompleted: OfflineAiBundle.extractionByteLength,
              embeddingCompleted: progress.completedBytes,
              stage: progress.stage,
              artifact: progress.artifact,
            );
          },
        );
        cancellation.throwIfCancelled();
        await embeddingEngine!.refresh();
      }

      reportCombined(
        extractionCompleted: OfflineAiBundle.extractionByteLength,
        embeddingCompleted: _includesEmbedding
            ? OfflineAiBundle.embeddingByteLength
            : 0,
        stage: ModelInstallStage.completed,
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
    await embeddingEngine?.cancel();
  }

  @override
  Future<void> removeRequired() async {
    await cancelInstallation();
    final manifest = await loadPhase7ModelManifest();
    final extractionLayout = await ModelInstallationLayout.appSupport();
    await installer.removeRequired(
      manifest: manifest,
      layout: extractionLayout,
    );
    if (_includesEmbedding) {
      final embeddingLayout = await ModelInstallationLayout.embeddingV3();
      await installer.removeArtifacts(
        artifacts: <ModelArtifactManifest>[OfflineAiBundle.embeddingArtifact],
        layout: embeddingLayout,
      );
      await embeddingEngine!.refresh();
    }
  }

  @override
  Future<void> close() => cancelInstallation();

  bool get _includesEmbedding {
    final engine = embeddingEngine;
    if (engine == null) return false;
    return engine.snapshot.capability !=
        EmbeddingCapability.unsupportedPlatform;
  }

  Future<ModelInstallationReport?> _inspectEmbedding() async {
    if (!_includesEmbedding) return null;
    final layout = await ModelInstallationLayout.embeddingV3();
    return installationInspector.inspectArtifacts(
      artifacts: <ModelArtifactManifest>[OfflineAiBundle.embeddingArtifact],
      layout: layout,
    );
  }
}
