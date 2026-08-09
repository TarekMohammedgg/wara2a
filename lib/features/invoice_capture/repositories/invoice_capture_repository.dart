import '../../invoice_details/repositories/invoice_repository.dart';
import '../../../core/ai/embedding/reviewed_invoice_indexer.dart';
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
    this.indexer,
  }) : _now = now ?? _utcNow;

  final InvoiceRepository _invoices;
  final DateTime Function() _now;
  final ReviewedInvoiceIndexer? indexer;

  @override
  Future<int> saveReviewedDraft(InvoiceDraft draft) async {
    final existing = draft.invoiceId == 0
        ? null
        : await _invoices.get(draft.invoiceId);
    final reviewedAt = _now();
    final invoiceId = await _invoices.save(
      InvoiceDraftMapper.toInvoice(
        draft,
        reviewedAt: reviewedAt,
        createdAt: existing?.createdAt,
      ),
    );
    try {
      await indexer?.indexReviewedInvoice(invoiceId);
    } on Object {
      // The reviewed invoice is already durable. The persisted pending/failed
      // state is retried locally and indexing never rolls back user data.
    }
    return invoiceId;
  }

  @override
  Future<InvoiceDraft?> getDraftForEditing(int invoiceId) async {
    final invoice = await _invoices.get(invoiceId);
    return invoice == null ? null : InvoiceDraftMapper.fromInvoice(invoice);
  }
}

DateTime _utcNow() => DateTime.now().toUtc();
