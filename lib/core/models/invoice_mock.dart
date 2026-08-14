import '../widgets/invoice_card_data.dart';

class InvoiceMock implements InvoiceCardData {
  const InvoiceMock({
    required this.merchant,
    required this.date,
    required this.total,
    required this.currency,
    required this.accent,
    required this.icon,
    this.number = '—',
    this.warranty = '12 شهر',
  });

  @override
  final String merchant;
  @override
  final String date;
  @override
  final String total;
  @override
  final String currency;
  final String number;
  final String warranty;
  @override
  final int accent;
  @override
  final int icon;
}

class InvoiceDraftMock {
  const InvoiceDraftMock({
    this.merchant = 'بي تك',
    this.date = '09 أغسطس 2026',
    this.number = 'BT-2026-0841',
    this.total = '24,999',
    this.currency = 'جنيه مصري',
    this.warranty = '12 شهر',
  });

  final String merchant;
  final String date;
  final String number;
  final String total;
  final String currency;
  final String warranty;
}
