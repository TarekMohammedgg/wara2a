import 'package:equatable/equatable.dart';

import '../../invoice_details/models/invoice.dart';

enum InvoiceDraftOrigin { extracted, repaired, manualFallback }

class InvoiceItemDraft extends Equatable {
  const InvoiceItemDraft({
    this.name,
    this.quantity,
    this.unitPriceMinor,
    this.lineTotalMinor,
  });

  final String? name;
  final double? quantity;
  final int? unitPriceMinor;
  final int? lineTotalMinor;

  @override
  List<Object?> get props => [name, quantity, unitPriceMinor, lineTotalMinor];
}

class InvoiceDraft extends Equatable {
  static const Object _unset = Object();

  const InvoiceDraft({
    this.invoiceId = 0,
    this.merchant,
    this.documentType,
    this.purchaseDate,
    this.invoiceNumber,
    this.totalMinor,
    String? currency,
    String? currencyCode,
    List<InvoiceItemDraft> products = const <InvoiceItemDraft>[],
    List<InvoiceItemDraft>? items,
    this.warrantyMonths,
    String rawText = '',
    String? rawExtractedText,
    this.imagePath = '',
    this.thumbnailPath,
    this.sourceType = InvoiceSourceType.gallery,
    this.extractionModelId,
    this.origin = InvoiceDraftOrigin.extracted,
    this.requiresManualReview = true,
  }) : currency = currencyCode ?? currency,
       products = items ?? products,
       rawText = rawExtractedText ?? rawText;

  factory InvoiceDraft.manualFallback({required String rawText}) =>
      InvoiceDraft(
        rawText: rawText,
        origin: InvoiceDraftOrigin.manualFallback,
        requiresManualReview: true,
      );

  final int invoiceId;
  final String? merchant;
  final String? documentType;
  final DateTime? purchaseDate;
  final String? invoiceNumber;
  final int? totalMinor;
  final String? currency;
  final List<InvoiceItemDraft> products;
  final int? warrantyMonths;
  final String rawText;
  final String imagePath;
  final String? thumbnailPath;
  final InvoiceSourceType sourceType;
  final String? extractionModelId;
  final InvoiceDraftOrigin origin;
  final bool requiresManualReview;

  String? get currencyCode {
    final value = currency;
    if (value != null && RegExp(r'^[A-Z]{3}$').hasMatch(value)) return value;
    return null;
  }

  List<InvoiceItemDraft> get items => products;

  String? get rawExtractedText => rawText.isEmpty ? null : rawText;

  InvoiceDraft copyWith({
    int? invoiceId,
    Object? merchant = _unset,
    Object? documentType = _unset,
    Object? purchaseDate = _unset,
    Object? invoiceNumber = _unset,
    Object? totalMinor = _unset,
    Object? currency = _unset,
    List<InvoiceItemDraft>? products,
    Object? warrantyMonths = _unset,
    String? rawText,
    String? imagePath,
    Object? thumbnailPath = _unset,
    InvoiceSourceType? sourceType,
    Object? extractionModelId = _unset,
    InvoiceDraftOrigin? origin,
    bool? requiresManualReview,
  }) {
    return InvoiceDraft(
      invoiceId: invoiceId ?? this.invoiceId,
      merchant: identical(merchant, _unset)
          ? this.merchant
          : merchant as String?,
      documentType: identical(documentType, _unset)
          ? this.documentType
          : documentType as String?,
      purchaseDate: identical(purchaseDate, _unset)
          ? this.purchaseDate
          : purchaseDate as DateTime?,
      invoiceNumber: identical(invoiceNumber, _unset)
          ? this.invoiceNumber
          : invoiceNumber as String?,
      totalMinor: identical(totalMinor, _unset)
          ? this.totalMinor
          : totalMinor as int?,
      currency: identical(currency, _unset)
          ? this.currency
          : currency as String?,
      products: products ?? this.products,
      warrantyMonths: identical(warrantyMonths, _unset)
          ? this.warrantyMonths
          : warrantyMonths as int?,
      rawText: rawText ?? this.rawText,
      imagePath: imagePath ?? this.imagePath,
      thumbnailPath: identical(thumbnailPath, _unset)
          ? this.thumbnailPath
          : thumbnailPath as String?,
      sourceType: sourceType ?? this.sourceType,
      extractionModelId: identical(extractionModelId, _unset)
          ? this.extractionModelId
          : extractionModelId as String?,
      origin: origin ?? this.origin,
      requiresManualReview: requiresManualReview ?? this.requiresManualReview,
    );
  }

  @override
  List<Object?> get props => [
    invoiceId,
    merchant,
    documentType,
    purchaseDate,
    invoiceNumber,
    totalMinor,
    currency,
    products,
    warrantyMonths,
    rawText,
    imagePath,
    thumbnailPath,
    sourceType,
    extractionModelId,
    origin,
    requiresManualReview,
  ];
}
