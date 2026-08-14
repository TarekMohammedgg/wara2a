import 'package:flutter_test/flutter_test.dart';
import 'package:wara2a/features/invoice_capture/models/invoice_draft.dart';
import 'package:wara2a/features/invoice_capture/repositories/invoice_draft_mapper.dart';
import 'package:wara2a/features/invoice_details/models/invoice.dart';

void main() {
  test('maps reviewed money, items, normalization, and warranty metadata', () {
    final reviewedAt = DateTime.utc(2026, 8, 9, 12);
    final invoice = InvoiceDraftMapper.toInvoice(
      InvoiceDraft(
        merchant: 'بـي تِك',
        purchaseDate: DateTime.utc(2026, 1, 31),
        totalMinor: 2499900,
        currencyCode: 'egp',
        warrantyMonths: 1,
        invoiceNumber: 'BT-١٢٣',
        imagePath: 'invoice.jpg',
        sourceType: InvoiceSourceType.gallery,
        items: const [InvoiceItemDraft(name: 'Samsung A56', quantity: 1)],
      ),
      reviewedAt: reviewedAt,
    );

    expect(invoice.totalMinor, 2499900);
    expect(invoice.keywordText, contains('bt 123'));
    expect(invoice.searchableText, contains('samsung a56 × 1'));
    expect(invoice.warrantyEndDate, DateTime.utc(2026, 2, 28));
    expect(invoice.reviewedAt, reviewedAt);
    expect(invoice.items.single.name, 'Samsung A56');
  });
}
