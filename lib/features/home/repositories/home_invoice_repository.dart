import '../../invoice_details/models/invoice.dart';
import '../../invoice_details/repositories/invoice_repository.dart';
import '../models/invoice_summary.dart';

abstract interface class HomeInvoiceRepository {
  Stream<List<InvoiceSummary>> watchRecent();
}

class LocalHomeInvoiceRepository implements HomeInvoiceRepository {
  const LocalHomeInvoiceRepository(this._invoices);

  final InvoiceRepository _invoices;

  @override
  Stream<List<InvoiceSummary>> watchRecent() => _invoices.watchAll().map(
    (invoices) => invoices.map(_toSummary).toList(growable: false),
  );

  InvoiceSummary _toSummary(Invoice invoice) {
    return InvoiceSummary(
      id: invoice.id,
      merchant: invoice.merchant?.trim().isNotEmpty == true
          ? invoice.merchant!.trim()
          : '—',
      category: invoice.documentType?.trim().isNotEmpty == true
          ? invoice.documentType!.trim()
          : '—',
      date: _formatDate(invoice.purchaseDate ?? invoice.reviewedAt),
      total: _formatMinor(invoice.totalMinor),
      currency: invoice.currencyCode ?? '',
      accent: 0xFF246BFD,
      icon: 0xFFEAF1FF,
    );
  }
}

String _formatMinor(int? minor) {
  if (minor == null) return '—';
  final absolute = minor.abs();
  final whole = absolute ~/ 100;
  final fraction = absolute % 100;
  final sign = minor < 0 ? '-' : '';
  return fraction == 0
      ? '$sign$whole'
      : '$sign$whole.${fraction.toString().padLeft(2, '0')}';
}

String _formatDate(DateTime date) {
  final local = date.toLocal();
  return '${local.year.toString().padLeft(4, '0')}-'
      '${local.month.toString().padLeft(2, '0')}-'
      '${local.day.toString().padLeft(2, '0')}';
}
