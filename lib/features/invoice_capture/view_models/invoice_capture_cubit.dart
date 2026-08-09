import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/storage/image_validation.dart';
import '../models/invoice_image_draft.dart';
import '../repositories/invoice_image_repository.dart';
import 'invoice_capture_state.dart';

class InvoiceCaptureCubit extends Cubit<InvoiceCaptureState> {
  InvoiceCaptureCubit(this._repository) : super(const InvoiceCaptureIdle());

  final InvoiceImageRepository _repository;

  Future<InvoiceImageDraft?> selectImage(InvoiceImageSource source) async {
    final previousDraft = state.draft;
    emit(InvoiceCaptureSelecting(draft: previousDraft));
    try {
      final draft = await _repository.pickImage(source);
      if (draft == null) {
        _restorePreviousDraft(previousDraft);
        return null;
      }
      if (previousDraft != null && previousDraft.path != draft.path) {
        await _repository.discardDraft(previousDraft);
      }
      emit(InvoiceCaptureReady(draft));
      return draft;
    } catch (error) {
      emit(
        InvoiceCaptureFailure(
          type: _failureTypeFor(error),
          draft: previousDraft,
        ),
      );
      return null;
    }
  }

  Future<InvoiceImageDraft?> recoverLostData() async {
    if (state is InvoiceCaptureSelecting) return state.draft;
    final previousDraft = state.draft;
    emit(InvoiceCaptureSelecting(draft: previousDraft));
    try {
      final draft = await _repository.recoverLostData();
      if (draft == null) {
        _restorePreviousDraft(previousDraft);
        return null;
      }
      if (previousDraft != null && previousDraft.path != draft.path) {
        await _repository.discardDraft(previousDraft);
      }
      emit(InvoiceCaptureRecovered(draft));
      return draft;
    } catch (error) {
      emit(
        InvoiceCaptureFailure(
          type: _failureTypeFor(error),
          draft: previousDraft,
        ),
      );
      return null;
    }
  }

  Future<void> discardCurrentDraft() async {
    final draft = state.draft;
    if (draft != null) {
      await _repository.discardDraft(draft);
    }
    emit(const InvoiceCaptureIdle());
  }

  void clearFailure() => _restorePreviousDraft(state.draft);

  void _restorePreviousDraft(InvoiceImageDraft? draft) {
    emit(
      draft == null ? const InvoiceCaptureIdle() : InvoiceCaptureReady(draft),
    );
  }

  CaptureImageFailureType _failureTypeFor(Object error) =>
      error is CaptureImageException
      ? error.type
      : CaptureImageFailureType.picker;
}
