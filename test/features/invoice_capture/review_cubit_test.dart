import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wara2a/features/invoice_capture/models/invoice_draft.dart';
import 'package:wara2a/features/invoice_capture/repositories/invoice_capture_repository.dart';
import 'package:wara2a/features/invoice_capture/view_models/review_cubit.dart';
import 'package:wara2a/features/invoice_details/models/invoice.dart';

void main() {
  const draft = InvoiceDraft(
    merchant: 'بي تك',
    imagePath: 'invoice.jpg',
    sourceType: InvoiceSourceType.camera,
    items: [],
  );

  blocTest<ReviewCubit, ReviewState>(
    'emits saving then saved only after repository confirmation',
    build: () => ReviewCubit(_CaptureRepository(), initialDraft: draft),
    act: (cubit) => cubit.save(draft),
    expect: () => [
      isA<ReviewState>().having(
        (state) => state.status,
        'status',
        ReviewStatus.saving,
      ),
      isA<ReviewState>()
          .having((state) => state.status, 'status', ReviewStatus.saved)
          .having((state) => state.savedInvoiceId, 'invoice id', 42),
    ],
  );
}

class _CaptureRepository implements InvoiceCaptureRepository {
  @override
  Future<InvoiceDraft?> getDraftForEditing(int invoiceId) async => null;

  @override
  Future<int> saveReviewedDraft(InvoiceDraft draft) async => 42;
}
