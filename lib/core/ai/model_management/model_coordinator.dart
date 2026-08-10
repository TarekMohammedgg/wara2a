import 'dart:async';

import '../../../features/invoice_capture/models/invoice_draft.dart';
import '../ai_cancellation_token.dart';
import '../ai_runtime_error.dart';
import '../extraction/invoice_draft_validator.dart';
import '../extraction/invoice_extraction_prompt.dart';
import '../extraction/invoice_text_interpreter.dart';
import '../ocr/ocr_engine.dart';
import '../ocr/ocr_evidence.dart';
import 'model_capability.dart';
import 'model_lifecycle_state.dart';

class InvoiceExtractionRequest {
  const InvoiceExtractionRequest({
    required this.imagePath,
    required this.ocrModels,
    required this.qwenModelPath,
    this.capabilityTimeout = const Duration(seconds: 5),
    this.ocrInitializationTimeout = const Duration(seconds: 15),
    this.ocrInferenceTimeout = const Duration(seconds: 30),
    this.interpreterInitializationTimeout = const Duration(seconds: 45),
    this.interpretationTimeout = const Duration(seconds: 60),
  });

  final String imagePath;
  final OcrModelFiles ocrModels;
  final String qwenModelPath;
  final Duration capabilityTimeout;
  final Duration ocrInitializationTimeout;
  final Duration ocrInferenceTimeout;
  final Duration interpreterInitializationTimeout;
  final Duration interpretationTimeout;
}

class InvoiceExtractionResult {
  const InvoiceExtractionResult({
    required this.draft,
    required this.manualFallback,
    required this.repaired,
    required this.validationIssues,
    this.evidence,
    this.modelOutput,
    this.error,
    this.interpretationElapsed,
    this.interpretationInputTokens,
  });

  final InvoiceDraft draft;
  final OcrEvidence? evidence;
  final bool manualFallback;
  final bool repaired;
  final List<DraftValidationIssue> validationIssues;
  final String? modelOutput;
  final AiRuntimeException? error;

  /// Diagnostics for the most recent interpreter attempt that completed.
  /// These remain available when validation or a later repair fails safely.
  final Duration? interpretationElapsed;
  final int? interpretationInputTokens;
}

class ModelCoordinator {
  ModelCoordinator({
    required this.ocrEngineFactory,
    required this.interpreterFactory,
    this.validator = const InvoiceDraftValidator(),
    this.promptBuilder = const InvoiceExtractionPromptBuilder(),
    this.runtimeControlTimeout = const Duration(seconds: 5),
  });

  final OcrEngineFactory ocrEngineFactory;
  final InvoiceTextInterpreterFactory interpreterFactory;
  final InvoiceDraftValidator validator;
  final InvoiceExtractionPromptBuilder promptBuilder;
  final Duration runtimeControlTimeout;
  final StreamController<ModelLifecycleState> _states =
      StreamController<ModelLifecycleState>.broadcast(sync: true);

  ModelLifecycleState _state = const ModelLifecycleState.notInstalled();
  AiCancellationToken? _activeCancellation;
  OcrEngine? _activeOcr;
  InvoiceTextInterpreter? _activeInterpreter;
  Completer<void>? _activeRunDone;
  bool _busy = false;
  bool _disposing = false;
  bool _disposed = false;

  Stream<ModelLifecycleState> get states => _states.stream;
  ModelLifecycleState get state => _state;

  Future<InvoiceExtractionResult> extract(
    InvoiceExtractionRequest request,
  ) async {
    _ensureUsable();
    if (_busy) {
      throw const AiRuntimeException(
        code: AiErrorCode.busy,
        stage: 'coordinator',
        message: 'Only one local extraction may run at a time.',
      );
    }
    _busy = true;
    final runDone = Completer<void>();
    _activeRunDone = runDone;
    final cancellation = AiCancellationToken();
    _activeCancellation = cancellation;
    OcrEvidence? evidence;
    var validationIssues = const <DraftValidationIssue>[];
    String? modelOutput;
    Duration? interpretationElapsed;
    int? interpretationInputTokens;
    try {
      _emit(ModelLifecycleStatus.loading, ExtractionStage.checkingCapability);
      final ocr = _activeOcr = ocrEngineFactory();
      final ocrCapability = await _runStage<ModelCapability>(
        operation: ocr.capability,
        timeout: request.capabilityTimeout,
        stage: 'ocr-capability',
        cancellation: cancellation,
        cancelRuntime: ocr.cancel,
      );
      if (!ocrCapability.canInitialize) {
        return _manualFallback(
          evidence: null,
          error: _capabilityError('ocr', ocrCapability),
        );
      }

      _emit(ModelLifecycleStatus.loading, ExtractionStage.loadingOcr);
      await _runStage<void>(
        operation: () =>
            ocr.initialize(request.ocrModels, cancellationToken: cancellation),
        timeout: request.ocrInitializationTimeout,
        stage: 'ocr-initialize',
        cancellation: cancellation,
        cancelRuntime: ocr.cancel,
      );
      _emit(ModelLifecycleStatus.running, ExtractionStage.readingImage);
      evidence = await _runStage<OcrEvidence>(
        operation: () => ocr.recognizeInvoice(
          request.imagePath,
          cancellationToken: cancellation,
        ),
        timeout: request.ocrInferenceTimeout,
        stage: 'ocr-inference',
        cancellation: cancellation,
        cancelRuntime: ocr.cancel,
      );
      if (evidence.lines.isEmpty ||
          evidence.lines.every(
            (line) => line.confidence < validator.minimumEvidenceConfidence,
          )) {
        return _manualFallback(
          evidence: evidence,
          error: const AiRuntimeException(
            code: AiErrorCode.invalidRuntimeResponse,
            stage: 'ocr-inference',
            message:
                'OCR returned no text with enough confidence for extraction.',
          ),
        );
      }
      await ocr.dispose();
      _activeOcr = null;

      _emit(ModelLifecycleStatus.loading, ExtractionStage.checkingCapability);
      final interpreter = _activeInterpreter = interpreterFactory();
      final interpreterCapability = await _runStage<ModelCapability>(
        operation: interpreter.capability,
        timeout: request.capabilityTimeout,
        stage: 'interpreter-capability',
        cancellation: cancellation,
        cancelRuntime: interpreter.cancel,
      );
      if (!interpreterCapability.canInitialize) {
        return _manualFallback(
          evidence: evidence,
          error: _capabilityError('interpreter', interpreterCapability),
        );
      }

      _emit(ModelLifecycleStatus.loading, ExtractionStage.loadingInterpreter);
      await _runStage<void>(
        operation: () => interpreter.initialize(
          request.qwenModelPath,
          cancellationToken: cancellation,
        ),
        timeout: request.interpreterInitializationTimeout,
        stage: 'interpreter-initialize',
        cancellation: cancellation,
        cancelRuntime: interpreter.cancel,
      );

      _emit(ModelLifecycleStatus.running, ExtractionStage.interpreting);
      final initial = await _runStage<InvoiceInterpretationOutput>(
        operation: () => interpreter.interpret(
          InvoiceInterpretationRequest(
            prompt: promptBuilder.buildInitial(evidence!),
            attempt: InterpretationAttempt.initial,
          ),
          cancellationToken: cancellation,
        ),
        timeout: request.interpretationTimeout,
        stage: 'interpretation',
        cancellation: cancellation,
        cancelRuntime: interpreter.cancel,
      );
      modelOutput = initial.json;
      interpretationElapsed = initial.elapsed;
      interpretationInputTokens = initial.inputTokens;
      _emit(ModelLifecycleStatus.running, ExtractionStage.validating);
      var validation = validator.validate(
        modelOutput: initial.json,
        evidence: evidence,
        origin: InvoiceDraftOrigin.extracted,
      );
      if (validation.isValid) {
        return _success(
          validation.draft!,
          evidence,
          initial.json,
          modelId: initial.modelId,
          interpretationElapsed: initial.elapsed,
          interpretationInputTokens: initial.inputTokens,
          repaired: false,
        );
      }

      validationIssues = validation.issues;
      _emit(ModelLifecycleStatus.running, ExtractionStage.repairing);
      final repaired = await _runStage<InvoiceInterpretationOutput>(
        operation: () => interpreter.interpret(
          InvoiceInterpretationRequest(
            prompt: promptBuilder.buildRepair(evidence!, validation.issues),
            attempt: InterpretationAttempt.repair,
          ),
          cancellationToken: cancellation,
        ),
        timeout: request.interpretationTimeout,
        stage: 'interpretation-repair',
        cancellation: cancellation,
        cancelRuntime: interpreter.cancel,
      );
      modelOutput = repaired.json;
      interpretationElapsed = repaired.elapsed;
      interpretationInputTokens = repaired.inputTokens;
      _emit(ModelLifecycleStatus.running, ExtractionStage.validating);
      validation = validator.validate(
        modelOutput: repaired.json,
        evidence: evidence,
        origin: InvoiceDraftOrigin.repaired,
      );
      if (validation.isValid) {
        return _success(
          validation.draft!,
          evidence,
          repaired.json,
          modelId: repaired.modelId,
          interpretationElapsed: repaired.elapsed,
          interpretationInputTokens: repaired.inputTokens,
          repaired: true,
        );
      }
      validationIssues = validation.issues;
      return _manualFallback(
        evidence: evidence,
        validationIssues: validation.issues,
        modelOutput: repaired.json,
        interpretationElapsed: repaired.elapsed,
        interpretationInputTokens: repaired.inputTokens,
        error: const AiRuntimeException(
          code: AiErrorCode.invalidModelOutput,
          stage: 'validation',
          message: 'The one permitted schema repair attempt was rejected.',
        ),
      );
    } on AiCancelledException catch (error) {
      _emit(
        ModelLifecycleStatus.failed,
        ExtractionStage.idle,
        message: error.toString(),
        errorCode: AiErrorCode.cancelled.name,
      );
      throw const AiRuntimeException(
        code: AiErrorCode.cancelled,
        stage: 'coordinator',
        message: 'The local extraction was cancelled.',
      );
    } on AiRuntimeException catch (error) {
      if (error.code == AiErrorCode.cancelled) rethrow;
      return _manualFallback(
        evidence: evidence,
        validationIssues: validationIssues,
        modelOutput: modelOutput,
        interpretationElapsed: interpretationElapsed,
        interpretationInputTokens: interpretationInputTokens,
        error: error,
      );
    } on Object catch (error) {
      return _manualFallback(
        evidence: evidence,
        validationIssues: validationIssues,
        modelOutput: modelOutput,
        interpretationElapsed: interpretationElapsed,
        interpretationInputTokens: interpretationInputTokens,
        error: AiRuntimeException(
          code: AiErrorCode.inferenceFailed,
          stage: 'coordinator',
          message: 'The local extraction failed safely.',
          cause: error,
        ),
      );
    } finally {
      await _disposeActiveRuntimesSafely();
      _activeCancellation = null;
      _busy = false;
      if (identical(_activeRunDone, runDone)) _activeRunDone = null;
      if (!runDone.isCompleted) runDone.complete();
    }
  }

  Future<void> cancel() async {
    if (!_busy || _disposed) return;
    _emit(ModelLifecycleStatus.cancelling, state.stage);
    _activeCancellation?.cancel();
    try {
      await Future.wait<void>(<Future<void>>[
        if (_activeOcr != null) _activeOcr!.cancel(),
        if (_activeInterpreter != null) _activeInterpreter!.cancel(),
      ]).timeout(runtimeControlTimeout);
    } on Object {
      // The Dart cancellation token still suppresses a late native result.
    }
  }

  Future<void> dispose() async {
    if (_disposed || _disposing) return;
    _disposing = true;
    try {
      final activeRunDone = _activeRunDone;
      if (_busy) await cancel();
      if (activeRunDone != null) await activeRunDone.future;
      await _disposeActiveRuntimesSafely();
      _disposed = true;
      _emit(ModelLifecycleStatus.disposed, ExtractionStage.idle);
      await _states.close();
    } finally {
      if (!_disposed) _disposing = false;
    }
  }

  Future<T> _runStage<T>({
    required Future<T> Function() operation,
    required Duration timeout,
    required String stage,
    required AiCancellationToken cancellation,
    required Future<void> Function() cancelRuntime,
  }) async {
    cancellation.throwIfCancelled();
    try {
      return await Future.any<T>(<Future<T>>[
        operation(),
        cancellation.whenCancelled.then<T>(
          (_) => throw const AiCancelledException(),
        ),
      ]).timeout(timeout);
    } on TimeoutException catch (error) {
      cancellation.cancel();
      try {
        await cancelRuntime().timeout(runtimeControlTimeout);
      } on Object {
        // Some native initialization calls are not interruptible. The engine
        // is disposed below and its eventual result is never observed.
      }
      throw AiRuntimeException(
        code: AiErrorCode.timeout,
        stage: stage,
        message: 'The $stage stage exceeded ${timeout.inSeconds} seconds.',
        cause: error,
      );
    }
  }

  InvoiceExtractionResult _success(
    InvoiceDraft draft,
    OcrEvidence evidence,
    String output, {
    required String modelId,
    required Duration interpretationElapsed,
    required int interpretationInputTokens,
    required bool repaired,
  }) {
    _emit(ModelLifecycleStatus.ready, ExtractionStage.completed);
    return InvoiceExtractionResult(
      draft: draft.copyWith(extractionModelId: modelId),
      evidence: evidence,
      manualFallback: false,
      repaired: repaired,
      validationIssues: const <DraftValidationIssue>[],
      modelOutput: output,
      interpretationElapsed: interpretationElapsed,
      interpretationInputTokens: interpretationInputTokens,
    );
  }

  InvoiceExtractionResult _manualFallback({
    required OcrEvidence? evidence,
    required AiRuntimeException error,
    List<DraftValidationIssue> validationIssues =
        const <DraftValidationIssue>[],
    String? modelOutput,
    Duration? interpretationElapsed,
    int? interpretationInputTokens,
  }) {
    _emit(
      ModelLifecycleStatus.failed,
      ExtractionStage.manualReview,
      message: error.message,
      errorCode: error.code.name,
      recoverable: error.recoverable,
    );
    return InvoiceExtractionResult(
      draft: InvoiceDraft.manualFallback(rawText: evidence?.rawText ?? ''),
      evidence: evidence,
      manualFallback: true,
      repaired: false,
      validationIssues: List.unmodifiable(validationIssues),
      modelOutput: modelOutput,
      error: error,
      interpretationElapsed: interpretationElapsed,
      interpretationInputTokens: interpretationInputTokens,
    );
  }

  AiRuntimeException _capabilityError(
    String stage,
    ModelCapability capability,
  ) {
    final code = switch (capability.status) {
      ModelCapabilityStatus.notInstalled => AiErrorCode.modelNotInstalled,
      ModelCapabilityStatus.incompatibleArtifact =>
        AiErrorCode.incompatibleArtifact,
      ModelCapabilityStatus.unsupportedPlatform =>
        AiErrorCode.unsupportedPlatform,
      _ => AiErrorCode.initializationFailed,
    };
    return AiRuntimeException(
      code: code,
      stage: stage,
      message: capability.reason,
    );
  }

  Future<void> _disposeActiveRuntimes() async {
    final ocr = _activeOcr;
    final interpreter = _activeInterpreter;
    _activeOcr = null;
    _activeInterpreter = null;
    await Future.wait<void>(<Future<void>>[
      if (ocr != null) ocr.dispose(),
      if (interpreter != null) interpreter.dispose(),
    ]);
  }

  Future<void> _disposeActiveRuntimesSafely() async {
    try {
      await _disposeActiveRuntimes().timeout(runtimeControlTimeout);
    } on TimeoutException {
      _emit(
        ModelLifecycleStatus.failed,
        ExtractionStage.manualReview,
        message:
            'A local runtime disposal timed out; restart is required before another extraction.',
        errorCode: AiErrorCode.timeout.name,
        recoverable: false,
      );
    } on Object catch (error) {
      _emit(
        ModelLifecycleStatus.failed,
        ExtractionStage.manualReview,
        message: 'A local runtime did not dispose cleanly: $error',
        errorCode: AiErrorCode.inferenceFailed.name,
        recoverable: false,
      );
    }
  }

  void _ensureUsable() {
    if (_disposed || _disposing) {
      throw const AiRuntimeException(
        code: AiErrorCode.disposed,
        stage: 'coordinator',
        message: 'The model coordinator has been disposed.',
        recoverable: false,
      );
    }
  }

  void _emit(
    ModelLifecycleStatus status,
    ExtractionStage stage, {
    String? message,
    double? progress,
    String? errorCode,
    bool recoverable = true,
  }) {
    _state = ModelLifecycleState(
      status: status,
      stage: stage,
      message: message,
      progress: progress,
      errorCode: errorCode,
      recoverable: recoverable,
    );
    if (!_states.isClosed) _states.add(_state);
  }
}
