import 'entities/invoice_entity.dart';
import 'entities/invoice_item_entity.dart';

class InvoiceRecord {
  const InvoiceRecord({required this.invoice, required this.items});

  final InvoiceEntity invoice;
  final List<InvoiceItemEntity> items;
}

class InvoiceWrite {
  const InvoiceWrite({required this.invoice, required this.items});

  final InvoiceEntity invoice;
  final List<InvoiceItemEntity> items;
}

class DeletedInvoiceFiles {
  const DeletedInvoiceFiles({required this.imagePath, this.thumbnailPath});

  final String imagePath;
  final String? thumbnailPath;
}
