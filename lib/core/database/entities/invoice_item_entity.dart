import 'package:objectbox/objectbox.dart';

@Entity()
class InvoiceItemEntity {
  InvoiceItemEntity({
    this.id = 0,
    required this.invoiceId,
    required this.name,
    required this.nameNormalized,
    this.quantity,
    this.unitPriceMinor,
    this.lineTotalMinor,
  });

  @Id()
  int id;

  @Index()
  int invoiceId;

  String name;
  String nameNormalized;
  double? quantity;
  int? unitPriceMinor;
  int? lineTotalMinor;
}
