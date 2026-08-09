import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../models/invoice_draft.dart';
import '../repositories/invoice_capture_repository.dart';

enum ReviewStatus { initial, loading, ready, saving, saved, failure }

class ReviewState extends Equatable {
  const ReviewState({
    this.status = ReviewStatus.initial,
    this.draft,
    this.savedInvoiceId,
    this.errorMessage,
  });

  final ReviewStatus status;
  final InvoiceDraft? draft;
  final int? savedInvoiceId;
  final String? errorMessage;

  @override
  List<Object?> get props => [status, draft, savedInvoiceId, errorMessage];
}

class ReviewCubit extends Cubit<ReviewState> {
  ReviewCubit(this._repository, {required InvoiceDraft initialDraft})
    : super(ReviewState(status: ReviewStatus.ready, draft: initialDraft));

  final InvoiceCaptureRepository _repository;

  Future<void> loadForEditing(int invoiceId) async {
    emit(const ReviewState(status: ReviewStatus.loading));
    try {
      final draft = await _repository.getDraftForEditing(invoiceId);
      emit(
        draft == null
            ? const ReviewState(
                status: ReviewStatus.failure,
                errorMessage: 'Invoice not found.',
              )
            : ReviewState(status: ReviewStatus.ready, draft: draft),
      );
    } catch (error) {
      emit(
        ReviewState(
          status: ReviewStatus.failure,
          errorMessage: error.toString(),
        ),
      );
    }
  }

  Future<void> save(InvoiceDraft draft) async {
    emit(ReviewState(status: ReviewStatus.saving, draft: draft));
    try {
      final id = await _repository.saveReviewedDraft(draft);
      emit(
        ReviewState(
          status: ReviewStatus.saved,
          draft: draft,
          savedInvoiceId: id,
        ),
      );
    } catch (error) {
      emit(
        ReviewState(
          status: ReviewStatus.failure,
          draft: draft,
          errorMessage: error.toString(),
        ),
      );
    }
  }
}
