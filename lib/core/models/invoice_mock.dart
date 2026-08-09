class InvoiceMock {
  const InvoiceMock({
    required this.merchant,
    required this.category,
    required this.date,
    required this.total,
    required this.currency,
    required this.accent,
    required this.icon,
    this.number = '—',
    this.warranty = '12 شهر',
  });

  final String merchant;
  final String category;
  final String date;
  final String total;
  final String currency;
  final String number;
  final String warranty;
  final int accent;
  final int icon;
}

class InvoiceDraftMock {
  const InvoiceDraftMock({
    this.merchant = 'بي تك',
    this.documentType = 'فاتورة شراء',
    this.date = '09 أغسطس 2026',
    this.number = 'BT-2026-0841',
    this.total = '24,999',
    this.currency = 'جنيه مصري',
    this.warranty = '12 شهر',
  });

  final String merchant;
  final String documentType;
  final String date;
  final String number;
  final String total;
  final String currency;
  final String warranty;
}
