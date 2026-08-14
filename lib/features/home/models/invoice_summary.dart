import '../../../core/widgets/invoice_card_data.dart';

class InvoiceSummary implements InvoiceCardData {
  const InvoiceSummary({
    required this.id,
    required this.merchant,
    required this.date,
    required this.total,
    required this.currency,
    required this.accent,
    required this.icon,
  });

  final int id;

  @override
  final String merchant;

  @override
  final String date;

  @override
  final String total;

  @override
  final String currency;

  @override
  final int accent;

  @override
  final int icon;
}
