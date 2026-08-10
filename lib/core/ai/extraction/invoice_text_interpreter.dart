import '../ai_cancellation_token.dart';
import '../ai_runtime_error.dart';
import '../model_management/model_capability.dart';
import 'invoice_extraction_prompt.dart';

const int defaultInvoiceMaximumOutputTokens = 384;

class InvoiceInterpretationRequest {
  const InvoiceInterpretationRequest({
    required this.prompt,
    required this.attempt,
    this.maximumOutputTokens = defaultInvoiceMaximumOutputTokens,
  });

  final String prompt;
  final InterpretationAttempt attempt;
  final int maximumOutputTokens;
}

class InvoiceInterpretationOutput {
  const InvoiceInterpretationOutput({
    required this.json,
    required this.modelId,
    required this.elapsed,
    required this.inputTokens,
  });

  final String json;
  final String modelId;
  final Duration elapsed;
  final int inputTokens;
}

abstract interface class InvoiceTextInterpreter {
  Future<ModelCapability> capability();
  Future<void> initialize(
    String modelPath, {
    AiCancellationToken? cancellationToken,
  });

  /// Each call must use a fresh or reset generation session. Implementations
  /// must not retain a rejected response in history for the repair attempt.
  Future<InvoiceInterpretationOutput> interpret(
    InvoiceInterpretationRequest request, {
    AiCancellationToken? cancellationToken,
  });
  Future<void> cancel();
  Future<void> dispose();
}

typedef InvoiceTextInterpreterFactory = InvoiceTextInterpreter Function();

/// The selected LiteRT-LM boundary remains explicit until a compatible
/// Qwen2.5-0.5B `.litertlm` artifact is published or reproducibly converted.
class IncompatibleQwenLiteRtInterpreter implements InvoiceTextInterpreter {
  const IncompatibleQwenLiteRtInterpreter();

  static const String reason =
      'The verified litert-community/Qwen2.5-0.5B-Instruct revision '
      '6c237a59eedeb06a821b21f0a59b03d346ac8bc3 contains .task/.tflite '
      'artifacts only. The selected LiteRT-LM runtime requires .litertlm; '
      'renaming or treating those containers as compatible would be invalid.';

  @override
  Future<ModelCapability> capability() async => const ModelCapability(
    status: ModelCapabilityStatus.incompatibleArtifact,
    runtime: 'LiteRT-LM',
    reason: reason,
    supportedFormats: <String>['litertlm'],
  );

  @override
  Future<void> initialize(
    String modelPath, {
    AiCancellationToken? cancellationToken,
  }) async {
    cancellationToken?.throwIfCancelled();
    throw const AiRuntimeException(
      code: AiErrorCode.incompatibleArtifact,
      stage: 'interpreter',
      message: reason,
    );
  }

  @override
  Future<InvoiceInterpretationOutput> interpret(
    InvoiceInterpretationRequest request, {
    AiCancellationToken? cancellationToken,
  }) async {
    cancellationToken?.throwIfCancelled();
    throw const AiRuntimeException(
      code: AiErrorCode.incompatibleArtifact,
      stage: 'interpreter',
      message: reason,
    );
  }

  @override
  Future<void> cancel() async {}

  @override
  Future<void> dispose() async {}
}
