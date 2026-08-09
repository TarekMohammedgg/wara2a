import '../models/invoice_mock.dart';
import '../../features/invoice_capture/models/invoice_draft.dart';
import '../../features/invoice_details/models/invoice.dart';

class MockData {
  const MockData._();

  static const invoices = [
    InvoiceMock(
      merchant: 'بي تك',
      category: 'إلكترونيات',
      date: 'اليوم، 10:42 ص',
      total: '24,999',
      currency: 'ج.م',
      accent: 0xFF246BFD,
      icon: 0xFFEAF1FF,
      number: 'BT-2026-0841',
    ),
    InvoiceMock(
      merchant: 'Carrefour',
      category: 'مستلزمات منزلية',
      date: 'أمس، 06:18 م',
      total: '1,248',
      currency: 'ج.م',
      accent: 0xFF19A67A,
      icon: 0xFFE9FAF4,
      number: 'CF-45892',
      warranty: '—',
    ),
    InvoiceMock(
      merchant: 'محطة موبيل',
      category: 'وقود',
      date: '05 أغسطس 2026',
      total: '720',
      currency: 'ج.م',
      accent: 0xFFE59B38,
      icon: 0xFFFFF6E8,
      number: 'MO-1190',
      warranty: '—',
    ),
  ];

  static final searchResults = <InvoiceMock>[invoices[0], invoices[1]];

  static final draft = InvoiceDraft(
    merchant: invoices.first.merchant,
    documentType: 'فاتورة شراء',
    purchaseDate: DateTime.utc(2026, 8, 9),
    totalMinor: 2499900,
    currencyCode: 'EGP',
    warrantyMonths: 12,
    invoiceNumber: invoices.first.number,
    rawExtractedText: 'Mock extraction remains active until Phase 7.',
    imagePath: 'assets/images/wara2a_logo.png',
    sourceType: InvoiceSourceType.camera,
    items: const [
      InvoiceItemDraft(
        name: 'Samsung Galaxy A56',
        quantity: 1,
        unitPriceMinor: 2499900,
        lineTotalMinor: 2499900,
      ),
      InvoiceItemDraft(name: 'ضمان ممتد'),
    ],
  );
}
