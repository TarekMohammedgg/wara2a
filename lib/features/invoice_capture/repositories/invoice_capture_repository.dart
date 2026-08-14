import 'dart:async';

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
    this.onIndexingScheduled,
  }) : _now = now ?? _utcNow;

  final InvoiceRepository _invoices;
  final DateTime Function() _now;
  final ReviewedInvoiceIndexer? indexer;

  /// Optional hook so the app can retry any leftovers in the background.
  final void Function()? onIndexingScheduled;

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
    // Indexing must not block save; pending leftovers are synced automatically.
    unawaited(_indexInBackground(invoiceId));
    return invoiceId;
  }

  Future<void> _indexInBackground(int invoiceId) async {
    try {
      await indexer?.indexReviewedInvoice(invoiceId);
    } on Object {
      // Durable invoice stays saved; automatic sync retries later.
    } finally {
      onIndexingScheduled?.call();
    }
  }

  @override
  Future<InvoiceDraft?> getDraftForEditing(int invoiceId) async {
    final invoice = await _invoices.get(invoiceId);
    return invoice == null ? null : InvoiceDraftMapper.fromInvoice(invoice);
  }
}

DateTime _utcNow() => DateTime.now().toUtc();
