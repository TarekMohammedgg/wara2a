import '../models/invoice_mock.dart';

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

  static const draft = InvoiceDraftMock();
}
