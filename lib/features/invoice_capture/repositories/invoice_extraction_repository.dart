import '../../../core/ai/ai_runtime_error.dart';
import '../../../core/ai/extraction/invoice_draft_validator.dart';
import '../../../core/ai/model_lifecycle_state.dart';
import '../models/invoice_draft.dart';
import '../models/invoice_image_draft.dart';

abstract interface class InvoiceExtractionRepository {
  Stream<ModelLifecycleState> get states;
  Future<InvoiceExtractionResult> extract(InvoiceImageDraft image);
  Future<void> cancel();
  Future<void> close();
}

class InvoiceExtractionResult {
  const InvoiceExtractionResult({
    required this.draft,
    required this.manualFallback,
    required this.repaired,
    required this.validationIssues,
    this.modelOutput,
    this.error,
    this.interpretationElapsed,
    this.interpretationInputTokens,
  });

  final InvoiceDraft draft;
  final bool manualFallback;
  final bool repaired;
  final List<DraftValidationIssue> validationIssues;
  final String? modelOutput;
  final AiRuntimeException? error;
  final Duration? interpretationElapsed;
  final int? interpretationInputTokens;
}
