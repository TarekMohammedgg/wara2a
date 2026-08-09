enum AiErrorCode {
  unsupportedPlatform,
  incompatibleArtifact,
  modelNotInstalled,
  modelVerificationFailed,
  invalidImage,
  initializationFailed,
  inferenceFailed,
  invalidRuntimeResponse,
  invalidModelOutput,
  timeout,
  cancelled,
  busy,
  disposed,
}

class AiRuntimeException implements Exception {
  const AiRuntimeException({
    required this.code,
    required this.message,
    this.stage,
    this.recoverable = true,
    this.cause,
  });

  final AiErrorCode code;
  final String message;
  final String? stage;
  final bool recoverable;
  final Object? cause;

  @override
  String toString() {
    final stageLabel = stage == null ? '' : ' [$stage]';
    return 'AiRuntimeException.${code.name}$stageLabel: $message';
  }
}
