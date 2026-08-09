import '../models/invoice_image_draft.dart';
import '../../../core/storage/image_validation.dart';

sealed class InvoiceCaptureState {
  const InvoiceCaptureState({this.draft});

  final InvoiceImageDraft? draft;
}

class InvoiceCaptureIdle extends InvoiceCaptureState {
  const InvoiceCaptureIdle();
}

class InvoiceCaptureSelecting extends InvoiceCaptureState {
  const InvoiceCaptureSelecting({super.draft});
}

class InvoiceCaptureReady extends InvoiceCaptureState {
  const InvoiceCaptureReady(InvoiceImageDraft draft) : super(draft: draft);
}

class InvoiceCaptureRecovered extends InvoiceCaptureReady {
  const InvoiceCaptureRecovered(super.draft);
}

class InvoiceCaptureFailure extends InvoiceCaptureState {
  const InvoiceCaptureFailure({required this.type, super.draft});

  final CaptureImageFailureType type;
}
