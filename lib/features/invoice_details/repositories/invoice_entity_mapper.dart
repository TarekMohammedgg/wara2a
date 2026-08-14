import '../../../core/database/entities/invoice_entity.dart';
import '../../../core/database/entities/invoice_item_entity.dart';
import '../../../core/database/invoice_embedding_status.dart';
import '../../../core/database/invoice_record.dart';
import '../../../core/utils/invoice_search_text_builder.dart';
import '../../../core/utils/text_normalization.dart';
import '../models/invoice.dart';

abstract final class InvoiceEntityMapper {
  static Invoice fromRecord(InvoiceRecord record) {
    final entity = record.invoice;
    return Invoice(
      id: entity.id,
      merchant: entity.merchant,
      purchaseDate: entity.purchaseDate,
      totalMinor: entity.totalMinor,
      currencyCode: entity.currencyCode,
      warrantyMonths: entity.warrantyMonths,
      warrantyEndDate: entity.warrantyEndDate,
      invoiceNumber: entity.invoiceNumber,
      rawExtractedText: entity.rawExtractedText,
      searchableText: entity.searchableText,
      keywordText: entity.keywordText,
      imagePath: entity.imagePath,
      thumbnailPath: entity.thumbnailPath,
      sourceType: _sourceTypeFromStorage(entity.sourceType),
      embedding: entity.embedding == null
          ? null
          : List<double>.unmodifiable(entity.embedding!),
      embeddingModelId: entity.embeddingModelId,
      embeddingDimensions: entity.embeddingDimensions,
      embeddingStatus: invoiceEmbeddingStatusFromStorage(
        entity.embeddingStatus,
      ),
      embeddingSchemaVersion: entity.embeddingSchemaVersion,
      embeddingUpdatedAt: entity.embeddingUpdatedAt,
      embeddingFailureCode: entity.embeddingFailureCode,
      embeddingAttemptId: entity.embeddingAttemptId,
      searchTextSchemaVersion: entity.searchTextSchemaVersion,
      extractionModelId: entity.extractionModelId,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
      reviewedAt: entity.reviewedAt,
      items: record.items
          .map(
            (item) => InvoiceItem(
              id: item.id,
              name: item.name,
              quantity: item.quantity,
              unitPriceMinor: item.unitPriceMinor,
              lineTotalMinor: item.lineTotalMinor,
            ),
          )
          .toList(growable: false),
    );
  }

  static InvoiceWrite toWrite(Invoice invoice) {
    return InvoiceWrite(
      invoice: InvoiceEntity(
        id: invoice.id,
        merchant: invoice.merchant,
        merchantNormalized: _nullableNormalize(invoice.merchant),
        purchaseDate: invoice.purchaseDate,
        totalMinor: invoice.totalMinor,
        currencyCode: invoice.currencyCode?.toUpperCase(),
        warrantyMonths: invoice.warrantyMonths,
        warrantyEndDate: invoice.warrantyEndDate,
        invoiceNumber: invoice.invoiceNumber,
        rawExtractedText: invoice.rawExtractedText,
        searchableText: invoice.searchableText,
        keywordText: invoice.keywordText,
        imagePath: invoice.imagePath,
        thumbnailPath: invoice.thumbnailPath,
        sourceType: invoice.sourceType.name,
        embedding: invoice.embedding == null
            ? null
            : List<double>.of(invoice.embedding!),
        embeddingModelId: invoice.embeddingModelId,
        embeddingDimensions: invoice.embeddingDimensions,
        embeddingStatus: invoice.embeddingStatus.storageValue,
        embeddingSchemaVersion: invoice.embeddingSchemaVersion,
        embeddingUpdatedAt: invoice.embeddingUpdatedAt,
        embeddingFailureCode: invoice.embeddingFailureCode,
        embeddingAttemptId: invoice.embeddingAttemptId,
        searchTextSchemaVersion: invoice.searchTextSchemaVersion,
        extractionModelId: invoice.extractionModelId,
        createdAt: invoice.createdAt,
        updatedAt: invoice.updatedAt,
        reviewedAt: invoice.reviewedAt,
      ),
      items: invoice.items
          .map(
            (item) => InvoiceItemEntity(
              invoiceId: invoice.id,
              name: item.name,
              nameNormalized: TextNormalization.normalize(item.name),
              quantity: item.quantity,
              unitPriceMinor: item.unitPriceMinor,
              lineTotalMinor: item.lineTotalMinor,
            ),
          )
          .toList(growable: false),
    );
  }

  static String buildKeywordText({
    String? merchant,
    String? invoiceNumber,
    required Iterable<String> itemNames,
  }) {
    return InvoiceSearchTextBuilder.build(
      merchant: merchant,
      invoiceNumber: invoiceNumber,
      items: itemNames.map((name) => InvoiceSearchItemInput(name: name)),
    ).keywordText;
  }

  static String buildSearchableText({
    String? merchant,
    String? invoiceNumber,
    DateTime? purchaseDate,
    int? totalMinor,
    String? currencyCode,
    int? warrantyMonths,
    DateTime? warrantyEndDate,
    required Iterable<String> itemNames,
  }) {
    return InvoiceSearchTextBuilder.build(
      merchant: merchant,
      invoiceNumber: invoiceNumber,
      purchaseDate: purchaseDate,
      totalMinor: totalMinor,
      currencyCode: currencyCode,
      warrantyMonths: warrantyMonths,
      warrantyEndDate: warrantyEndDate,
      items: itemNames.map((name) => InvoiceSearchItemInput(name: name)),
    ).searchableText;
  }

  static InvoiceSourceType _sourceTypeFromStorage(String value) {
    return InvoiceSourceType.values.firstWhere(
      (type) => type.name == value,
      orElse: () => InvoiceSourceType.gallery,
    );
  }

  static String? _nullableNormalize(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return TextNormalization.normalize(value);
  }
}
