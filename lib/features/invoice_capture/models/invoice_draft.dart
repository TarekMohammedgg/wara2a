import 'package:equatable/equatable.dart';

import '../../invoice_details/models/invoice.dart';

class InvoiceItemDraft extends Equatable {
  const InvoiceItemDraft({
    required this.name,
    this.quantity,
    this.unitPriceMinor,
    this.lineTotalMinor,
  });

  final String name;
  final double? quantity;
  final int? unitPriceMinor;
  final int? lineTotalMinor;

  @override
  List<Object?> get props => [name, quantity, unitPriceMinor, lineTotalMinor];
}

class InvoiceDraft extends Equatable {
  const InvoiceDraft({
    this.invoiceId = 0,
    this.merchant,
    this.documentType,
    this.purchaseDate,
    this.totalMinor,
    this.currencyCode,
    this.warrantyMonths,
    this.invoiceNumber,
    this.rawExtractedText,
    required this.imagePath,
    this.thumbnailPath,
    required this.sourceType,
    this.extractionModelId,
    required this.items,
  });

  final int invoiceId;
  final String? merchant;
  final String? documentType;
  final DateTime? purchaseDate;
  final int? totalMinor;
  final String? currencyCode;
  final int? warrantyMonths;
  final String? invoiceNumber;
  final String? rawExtractedText;
  final String imagePath;
  final String? thumbnailPath;
  final InvoiceSourceType sourceType;
  final String? extractionModelId;
  final List<InvoiceItemDraft> items;

  @override
  List<Object?> get props => [
    invoiceId,
    merchant,
    documentType,
    purchaseDate,
    totalMinor,
    currencyCode,
    warrantyMonths,
    invoiceNumber,
    rawExtractedText,
    imagePath,
    thumbnailPath,
    sourceType,
    extractionModelId,
    items,
  ];
}
