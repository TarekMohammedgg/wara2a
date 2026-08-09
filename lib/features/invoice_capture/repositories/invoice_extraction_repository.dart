import 'dart:io';

import '../../../core/ai/ai_runtime_error.dart';
import '../../../core/ai/model_management/bundled_model_manifest.dart';
import '../../../core/ai/model_management/model_installation.dart';
import '../../../core/ai/model_management/model_coordinator.dart';
import '../../../core/ai/model_management/model_lifecycle_state.dart';
import '../../invoice_details/models/invoice.dart';
import '../models/invoice_draft.dart';
import '../models/invoice_image_draft.dart';

abstract interface class InvoiceExtractionRepository {
  Stream<ModelLifecycleState> get states;
  Future<InvoiceExtractionResult> extract(InvoiceImageDraft image);
  Future<void> cancel();
  Future<void> close();
}

class LocalInvoiceExtractionRepository implements InvoiceExtractionRepository {
  LocalInvoiceExtractionRepository(
    this.coordinator, {
    this.installationInspector = const ModelInstallationInspector(),
  });

  final ModelCoordinator coordinator;
  final ModelInstallationInspector installationInspector;

  @override
  Stream<ModelLifecycleState> get states => coordinator.states;

  @override
  Future<InvoiceExtractionResult> extract(InvoiceImageDraft image) async {
    if (!await File(image.path).exists()) {
      return _manualResult(
        image,
        const AiRuntimeException(
          code: AiErrorCode.invalidImage,
          stage: 'image',
          message: 'The durable invoice image is no longer available.',
        ),
      );
    }
    final manifest = await loadPhase7ModelManifest();
    final layout = await ModelInstallationLayout.appSupport();
    final installation = await installationInspector.inspectRequired(
      manifest: manifest,
      layout: layout,
    );
    if (!installation.isReady) {
      return _manualResult(
        image,
        AiRuntimeException(
          code: installation.hasCorruptFile
              ? AiErrorCode.modelVerificationFailed
              : AiErrorCode.modelNotInstalled,
          stage: 'model-verify',
          message: installation.hasCorruptFile
              ? 'A required local model failed byte-length or SHA-256 verification.'
              : 'Install and verify the offline OCR and Qwen models first.',
        ),
      );
    }
    final result = await coordinator.extract(
      InvoiceExtractionRequest(
        imagePath: image.path,
        ocrModels: layout.ocrFiles(manifest),
        qwenModelPath: layout.qwenModelPath(manifest),
      ),
    );
    return _attachImage(result, image);
  }

  @override
  Future<void> cancel() => coordinator.cancel();

  @override
  Future<void> close() => coordinator.dispose();

  InvoiceExtractionResult _manualResult(
    InvoiceImageDraft image,
    AiRuntimeException error,
  ) => _attachImage(
    InvoiceExtractionResult(
      draft: InvoiceDraft.manualFallback(rawText: ''),
      manualFallback: true,
      repaired: false,
      validationIssues: const [],
      error: error,
    ),
    image,
  );

  InvoiceExtractionResult _attachImage(
    InvoiceExtractionResult result,
    InvoiceImageDraft image,
  ) {
    final draft = result.draft.copyWith(
      imagePath: image.path,
      sourceType: image.source == InvoiceImageSource.camera
          ? InvoiceSourceType.camera
          : InvoiceSourceType.gallery,
    );
    return InvoiceExtractionResult(
      draft: draft,
      evidence: result.evidence,
      manualFallback: result.manualFallback,
      repaired: result.repaired,
      validationIssues: result.validationIssues,
      modelOutput: result.modelOutput,
      error: result.error,
      interpretationElapsed: result.interpretationElapsed,
    );
  }
}
