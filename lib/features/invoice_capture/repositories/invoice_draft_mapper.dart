import '../../../core/database/database_versions.dart';
import '../../invoice_details/models/invoice.dart';
import '../../invoice_details/repositories/invoice_entity_mapper.dart';
import '../models/invoice_draft.dart';

abstract final class InvoiceDraftMapper {
  static Invoice toInvoice(
    InvoiceDraft draft, {
    required DateTime reviewedAt,
    DateTime? createdAt,
  }) {
    final itemNames = draft.items.map((item) => item.name);
    final warrantyEndDate = _warrantyEndDate(
      draft.purchaseDate,
      draft.warrantyMonths,
    );
    return Invoice(
      id: draft.invoiceId,
      merchant: draft.merchant,
      documentType: draft.documentType,
      purchaseDate: draft.purchaseDate,
      totalMinor: draft.totalMinor,
      currencyCode: draft.currencyCode,
      warrantyMonths: draft.warrantyMonths,
      warrantyEndDate: warrantyEndDate,
      invoiceNumber: draft.invoiceNumber,
      rawExtractedText: draft.rawExtractedText,
      searchableText: InvoiceEntityMapper.buildSearchableText(
        merchant: draft.merchant,
        documentType: draft.documentType,
        invoiceNumber: draft.invoiceNumber,
        purchaseDate: draft.purchaseDate,
        totalMinor: draft.totalMinor,
        currencyCode: draft.currencyCode,
        warrantyMonths: draft.warrantyMonths,
        warrantyEndDate: warrantyEndDate,
        itemNames: itemNames,
      ),
      keywordText: InvoiceEntityMapper.buildKeywordText(
        merchant: draft.merchant,
        invoiceNumber: draft.invoiceNumber,
        itemNames: itemNames,
      ),
      imagePath: draft.imagePath,
      thumbnailPath: draft.thumbnailPath,
      sourceType: draft.sourceType,
      searchTextSchemaVersion: DatabaseVersions.searchTextSchema,
      extractionModelId: draft.extractionModelId,
      createdAt: createdAt ?? reviewedAt,
      updatedAt: reviewedAt,
      reviewedAt: reviewedAt,
      items: draft.items
          .map(
            (item) => InvoiceItem(
              name: item.name,
              quantity: item.quantity,
              unitPriceMinor: item.unitPriceMinor,
              lineTotalMinor: item.lineTotalMinor,
            ),
          )
          .toList(growable: false),
    );
  }

  static InvoiceDraft fromInvoice(Invoice invoice) {
    return InvoiceDraft(
      invoiceId: invoice.id,
      merchant: invoice.merchant,
      documentType: invoice.documentType,
      purchaseDate: invoice.purchaseDate,
      totalMinor: invoice.totalMinor,
      currencyCode: invoice.currencyCode,
      warrantyMonths: invoice.warrantyMonths,
      invoiceNumber: invoice.invoiceNumber,
      rawExtractedText: invoice.rawExtractedText,
      imagePath: invoice.imagePath,
      thumbnailPath: invoice.thumbnailPath,
      sourceType: invoice.sourceType,
      extractionModelId: invoice.extractionModelId,
      items: invoice.items
          .map(
            (item) => InvoiceItemDraft(
              name: item.name,
              quantity: item.quantity,
              unitPriceMinor: item.unitPriceMinor,
              lineTotalMinor: item.lineTotalMinor,
            ),
          )
          .toList(growable: false),
    );
  }

  static DateTime? _warrantyEndDate(DateTime? date, int? months) {
    if (date == null || months == null) return null;
    final targetMonth = date.month - 1 + months;
    final year = date.year + targetMonth ~/ 12;
    final month = targetMonth % 12 + 1;
    final finalDay = DateTime(year, month + 1, 0).day;
    return DateTime.utc(year, month, date.day.clamp(1, finalDay));
  }
}
