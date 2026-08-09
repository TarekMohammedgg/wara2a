enum ModelLifecycleStatus {
  unavailable,
  notInstalled,
  downloading,
  verifying,
  ready,
  loading,
  running,
  cancelling,
  failed,
  disposed,
}

enum ExtractionStage {
  idle,
  checkingCapability,
  verifyingModels,
  loadingOcr,
  readingImage,
  loadingInterpreter,
  interpreting,
  validating,
  repairing,
  manualReview,
  completed,
}

class ModelLifecycleState {
  const ModelLifecycleState({
    required this.status,
    required this.stage,
    this.message,
    this.progress,
    this.errorCode,
    this.recoverable = true,
  }) : assert(progress == null || (progress >= 0 && progress <= 1));

  const ModelLifecycleState.notInstalled({String? message})
    : this(
        status: ModelLifecycleStatus.notInstalled,
        stage: ExtractionStage.idle,
        message: message,
      );

  final ModelLifecycleStatus status;
  final ExtractionStage stage;
  final String? message;
  final double? progress;
  final String? errorCode;
  final bool recoverable;
}
