import 'dart:async';
import 'dart:io';

import '../../../core/ai/ai_cancellation_token.dart';
import '../../../core/ai/ai_runtime_error.dart';
import '../../../core/ai/cloud/invoice_vision_image_preparer.dart';
import '../../../core/ai/cloud/open_router_client.dart';
import '../../../core/ai/cloud/open_router_config.dart';
import '../../../core/ai/cloud/open_router_invoice_prompt.dart';
import '../../../core/ai/extraction/invoice_draft_validator.dart';
import '../../../core/ai/model_lifecycle_state.dart';
import '../../invoice_details/models/invoice.dart';
import '../models/invoice_draft.dart';
import '../models/invoice_image_draft.dart';
import 'invoice_extraction_repository.dart';

typedef OpenRouterApiKeyResolver = Future<String?> Function();

/// Cloud path: invoice image → OpenRouter Gemini → JSON schema.
class OpenRouterGeminiExtractionRepository
    implements InvoiceExtractionRepository {
  OpenRouterGeminiExtractionRepository({
    required OpenRouterApiKeyResolver resolveApiKey,
    OpenRouterClient Function(OpenRouterConfig config)? clientFactory,
    this.validator = const InvoiceDraftValidator(),
    this.prompt = const OpenRouterInvoicePrompt(),
    this.imagePreparer = const InvoiceVisionImagePreparer(),
  }) : _resolveApiKey = resolveApiKey,
       _clientFactory =
           clientFactory ?? ((config) => OpenRouterClient(config: config));

  final InvoiceDraftValidator validator;
  final OpenRouterInvoicePrompt prompt;
  final InvoiceVisionImagePreparer imagePreparer;
  final OpenRouterApiKeyResolver _resolveApiKey;
  final OpenRouterClient Function(OpenRouterConfig config) _clientFactory;
  final StreamController<ModelLifecycleState> _states =
      StreamController<ModelLifecycleState>.broadcast(sync: true);
  final AiCancellationBridge _cancellation = AiCancellationBridge();
  OpenRouterClient? _client;
  String? _clientApiKey;
  bool _closed = false;

  @override
  Stream<ModelLifecycleState> get states => _states.stream;

  @override
  Future<InvoiceExtractionResult> extract(InvoiceImageDraft image) async {
    _ensureOpen();
    _cancellation.reset();
    try {
      _emit(ModelLifecycleStatus.loading, ExtractionStage.preparing);
      final apiKey = OpenRouterConfig.resolveApiKey(await _resolveApiKey());
      if (apiKey == null) {
        return _manualResult(
          image,
          const AiRuntimeException(
            code: AiErrorCode.modelNotInstalled,
            stage: 'openrouter',
            message:
                'Add an OpenRouter API key in Settings before extracting invoices.',
          ),
        );
      }
      final client = _clientFor(apiKey);

      _emit(ModelLifecycleStatus.loading, ExtractionStage.readingImage);
      final file = File(image.path);
      if (!await file.exists()) {
        return _manualResult(
          image,
          const AiRuntimeException(
            code: AiErrorCode.invalidImage,
            stage: 'image',
            message: 'The durable invoice image is no longer available.',
          ),
        );
      }
      final bytes = await file.readAsBytes();
      _cancellation.throwIfCancelled();
      final prepared = await imagePreparer.prepare(
        bytes,
        sourceMimeType: _mimeTypeFor(image.path),
      );
      _cancellation.throwIfCancelled();

      _emit(ModelLifecycleStatus.running, ExtractionStage.interpreting);
      final completion = await client.complete(
        OpenRouterCompletionRequest(
          prompt: prompt.build(),
          imageBytes: prepared.bytes,
          mimeType: prepared.mimeType,
        ),
        isCancelled: () => _cancellation.isCancelled,
      );
      _cancellation.throwIfCancelled();

      _emit(ModelLifecycleStatus.running, ExtractionStage.validating);
      final json = OpenRouterInvoicePrompt.extractJsonObject(
        completion.content,
      );
      final validation = validator.validate(
        modelOutput: json,
        origin: InvoiceDraftOrigin.extracted,
      );
      if (!validation.isValid || validation.draft == null) {
        return _manualResult(
          image,
          const AiRuntimeException(
            code: AiErrorCode.invalidModelOutput,
            stage: 'validation',
            message: 'Gemini JSON failed schema validation.',
          ),
          modelOutput: json,
          interpretationElapsed: completion.elapsed,
          interpretationInputTokens: completion.promptTokens,
          validationIssues: validation.issues,
        );
      }

      _emit(ModelLifecycleStatus.ready, ExtractionStage.completed);
      return _attachImage(
        InvoiceExtractionResult(
          draft: validation.draft!.copyWith(
            extractionModelId: completion.modelId,
            requiresManualReview: true,
          ),
          manualFallback: false,
          repaired: false,
          validationIssues: const [],
          modelOutput: json,
          interpretationElapsed: completion.elapsed,
          interpretationInputTokens: completion.promptTokens,
        ),
        image,
      );
    } on AiCancelledException {
      _emit(
        ModelLifecycleStatus.failed,
        ExtractionStage.idle,
        errorCode: 'cancelled',
      );
      throw const AiRuntimeException(
        code: AiErrorCode.cancelled,
        stage: 'openrouter',
        message: 'The cloud extraction was cancelled.',
      );
    } on AiRuntimeException catch (error) {
      if (error.code == AiErrorCode.cancelled) rethrow;
      return _manualResult(image, error);
    } on Object catch (error) {
      return _manualResult(
        image,
        AiRuntimeException(
          code: AiErrorCode.inferenceFailed,
          stage: 'openrouter',
          message: 'Cloud invoice extraction failed.',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<void> cancel() async {
    _cancellation.cancel();
    _emit(ModelLifecycleStatus.cancelling, ExtractionStage.idle);
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _cancellation.cancel();
    await _client?.close();
    _client = null;
    _clientApiKey = null;
    await _states.close();
  }

  OpenRouterClient _clientFor(String apiKey) {
    if (_client != null && _clientApiKey == apiKey) return _client!;
    unawaited(_client?.close());
    _client = _clientFactory(OpenRouterConfig(apiKey: apiKey));
    _clientApiKey = apiKey;
    return _client!;
  }

  void _emit(
    ModelLifecycleStatus status,
    ExtractionStage stage, {
    String? message,
    String? errorCode,
  }) {
    if (_states.isClosed) return;
    _states.add(
      ModelLifecycleState(
        status: status,
        stage: stage,
        message: message,
        errorCode: errorCode,
      ),
    );
  }

  InvoiceExtractionResult _manualResult(
    InvoiceImageDraft image,
    AiRuntimeException error, {
    String? modelOutput,
    Duration? interpretationElapsed,
    int? interpretationInputTokens,
    List<DraftValidationIssue> validationIssues = const [],
  }) {
    _emit(
      ModelLifecycleStatus.failed,
      ExtractionStage.manualReview,
      message: error.message,
      errorCode: error.code.name,
    );
    return _attachImage(
      InvoiceExtractionResult(
        draft: InvoiceDraft.manualFallback(rawText: ''),
        manualFallback: true,
        repaired: false,
        validationIssues: validationIssues,
        modelOutput: modelOutput,
        error: error,
        interpretationElapsed: interpretationElapsed,
        interpretationInputTokens: interpretationInputTokens,
      ),
      image,
    );
  }

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
      manualFallback: result.manualFallback,
      repaired: result.repaired,
      validationIssues: result.validationIssues,
      modelOutput: result.modelOutput,
      error: result.error,
      interpretationElapsed: result.interpretationElapsed,
      interpretationInputTokens: result.interpretationInputTokens,
    );
  }

  String _mimeTypeFor(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    return 'image/jpeg';
  }

  void _ensureOpen() {
    if (_closed) {
      throw const AiRuntimeException(
        code: AiErrorCode.disposed,
        stage: 'openrouter',
        message: 'The cloud extraction repository was closed.',
      );
    }
  }
}

/// Small resettable cancellation bridge for one extract attempt.
class AiCancellationBridge {
  Completer<void> _completer = Completer<void>();

  bool get isCancelled => _completer.isCompleted;

  void reset() {
    _completer = Completer<void>();
  }

  void cancel() {
    if (!_completer.isCompleted) _completer.complete();
  }

  void throwIfCancelled() {
    if (_completer.isCompleted) throw const AiCancelledException();
  }
}
