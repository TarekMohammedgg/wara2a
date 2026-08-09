import '../../invoice_details/repositories/invoice_repository.dart';
import '../models/invoice_draft.dart';
import 'invoice_draft_mapper.dart';

abstract interface class InvoiceCaptureRepository {
  Future<int> saveReviewedDraft(InvoiceDraft draft);
  Future<InvoiceDraft?> getDraftForEditing(int invoiceId);
}

class LocalInvoiceCaptureRepository implements InvoiceCaptureRepository {
  const LocalInvoiceCaptureRepository(
    this._invoices, {
    DateTime Function()? now,
  }) : _now = now ?? _utcNow;

  final InvoiceRepository _invoices;
  final DateTime Function() _now;

  @override
  Future<int> saveReviewedDraft(InvoiceDraft draft) async {
    final existing = draft.invoiceId == 0
        ? null
        : await _invoices.get(draft.invoiceId);
    final reviewedAt = _now();
    return _invoices.save(
      InvoiceDraftMapper.toInvoice(
        draft,
        reviewedAt: reviewedAt,
        createdAt: existing?.createdAt,
      ),
    );
  }

  @override
  Future<InvoiceDraft?> getDraftForEditing(int invoiceId) async {
    final invoice = await _invoices.get(invoiceId);
    return invoice == null ? null : InvoiceDraftMapper.fromInvoice(invoice);
  }
}

DateTime _utcNow() => DateTime.now().toUtc();
