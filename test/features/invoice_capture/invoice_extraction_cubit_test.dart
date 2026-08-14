import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wara2a/core/ai/ai_runtime_error.dart';
import 'package:wara2a/core/ai/model_lifecycle_state.dart';
import 'package:wara2a/features/invoice_capture/models/invoice_draft.dart';
import 'package:wara2a/features/invoice_capture/models/invoice_image_draft.dart';
import 'package:wara2a/features/invoice_capture/repositories/invoice_extraction_repository.dart';
import 'package:wara2a/features/invoice_capture/view_models/invoice_extraction_cubit.dart';

void main() {
  blocTest<InvoiceExtractionCubit, InvoiceExtractionState>(
    'emits a manual-review-ready result when extraction falls back safely',
    build: () {
      final result = InvoiceExtractionResult(
        draft: InvoiceDraft.manualFallback(rawText: 'الإجمالي ١٠٠'),
        manualFallback: true,
        repaired: false,
        validationIssues: const [],
        error: const AiRuntimeException(
          code: AiErrorCode.invalidRuntimeResponse,
          stage: 'openrouter',
          message: 'Cloud extraction could not finish.',
        ),
      );
      return InvoiceExtractionCubit(_FakeExtractionRepository(result: result));
    },
    act: (cubit) => cubit.extract(_image()),
    expect: () => <Object>[
      isA<InvoiceExtractionRunning>(),
      isA<InvoiceExtractionManualReview>(),
    ],
    verify: (cubit) {
      final state = cubit.state as InvoiceExtractionManualReview;
      expect(state.result.draft.rawText, 'الإجمالي ١٠٠');
      expect(state.result.draft.requiresManualReview, isTrue);
    },
  );

  blocTest<InvoiceExtractionCubit, InvoiceExtractionState>(
    'maps cancellation to an explicit cancelled state',
    build: () => InvoiceExtractionCubit(
      _FakeExtractionRepository(
        error: const AiRuntimeException(
          code: AiErrorCode.cancelled,
          message: 'Cancelled.',
        ),
      ),
    ),
    act: (cubit) => cubit.extract(_image()),
    expect: () => <Object>[
      isA<InvoiceExtractionRunning>(),
      isA<InvoiceExtractionCancelled>(),
    ],
  );
}

InvoiceImageDraft _image() => InvoiceImageDraft(
  id: 'fixture',
  path: 'fixture.png',
  source: InvoiceImageSource.gallery,
  mimeType: 'image/png',
  byteLength: 1,
  width: 1,
  height: 1,
  createdAt: DateTime.utc(2026),
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
  Future<InvoiceExtractionResult> extract(InvoiceImageDraft image) async {
    final failure = error;
    if (failure != null) throw failure;
    return result!;
  }

  @override
  Future<void> cancel() async {}

  @override
  Future<void> close() => _states.close();
}
