import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wara2a/core/ai/ai_runtime_error.dart';
import 'package:wara2a/core/ai/extraction/invoice_draft_validator.dart';
import 'package:wara2a/core/ai/model_management/model_coordinator.dart';
import 'package:wara2a/core/ai/model_management/model_lifecycle_state.dart';
import 'package:wara2a/core/ai/ocr/ocr_engine.dart';
import 'package:wara2a/features/invoice_capture/models/invoice_draft.dart';
import 'package:wara2a/features/invoice_capture/repositories/invoice_extraction_repository.dart';
import 'package:wara2a/features/invoice_capture/view_models/invoice_extraction_cubit.dart';

void main() {
  blocTest<InvoiceExtractionCubit, InvoiceExtractionState>(
    'emits a manual-review-ready result when local interpretation is gated',
    build: () {
      final result = InvoiceExtractionResult(
        draft: InvoiceDraft.manualFallback(rawText: 'الإجمالي ١٠٠'),
        manualFallback: true,
        repaired: false,
        validationIssues: const <DraftValidationIssue>[],
        error: const AiRuntimeException(
          code: AiErrorCode.incompatibleArtifact,
          message: 'A compatible LiteRT-LM container is unavailable.',
        ),
      );
      return InvoiceExtractionCubit(_FakeExtractionRepository(result: result));
    },
    act: (cubit) => cubit.extract(_request()),
    expect: () => <Object>[isA<InvoiceExtractionManualReview>()],
    verify: (cubit) {
      final state = cubit.state as InvoiceExtractionManualReview;
      expect(state.result.draft.rawText, 'الإجمالي ١٠٠');
      expect(state.result.draft.requiresManualReview, isTrue);
    },
  );

  blocTest<InvoiceExtractionCubit, InvoiceExtractionState>(
    'maps coordinator cancellation to an explicit cancelled state',
    build: () => InvoiceExtractionCubit(
      _FakeExtractionRepository(
        error: const AiRuntimeException(
          code: AiErrorCode.cancelled,
          message: 'Cancelled.',
        ),
      ),
    ),
    act: (cubit) => cubit.extract(_request()),
    expect: () => <Object>[isA<InvoiceExtractionCancelled>()],
  );
}

InvoiceExtractionRequest _request() => const InvoiceExtractionRequest(
  imagePath: 'fixture.png',
  ocrModels: OcrModelFiles(
    detectorModelPath: 'det.onnx',
    detectorConfigPath: 'det.yml',
    arabicModelPath: 'ar.onnx',
    arabicConfigPath: 'ar.yml',
    latinModelPath: 'latin.onnx',
    latinConfigPath: 'latin.yml',
  ),
);

class _FakeExtractionRepository implements InvoiceExtractionRepository {
  _FakeExtractionRepository({this.result, this.error});

  final InvoiceExtractionResult? result;
  final AiRuntimeException? error;
  final StreamController<ModelLifecycleState> _states =
      StreamController<ModelLifecycleState>.broadcast();

  @override
  Stream<ModelLifecycleState> get states => _states.stream;

  @override
  Future<InvoiceExtractionResult> extract(
    InvoiceExtractionRequest request,
  ) async {
    final failure = error;
    if (failure != null) throw failure;
    return result!;
  }

  @override
  Future<void> cancel() async {}

  @override
  Future<void> close() => _states.close();
}
