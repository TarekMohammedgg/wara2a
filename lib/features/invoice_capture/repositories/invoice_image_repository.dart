import '../models/invoice_image_draft.dart';

abstract interface class InvoiceImageRepository {
  /// Returns null when the system picker is cancelled.
  Future<InvoiceImageDraft?> pickImage(InvoiceImageSource source);

  /// Restores an Android picker result after process recreation when available.
  Future<InvoiceImageDraft?> recoverLostData();

  /// Deletes only files that were created for an uncommitted capture draft.
  Future<void> discardDraft(InvoiceImageDraft draft);
}
