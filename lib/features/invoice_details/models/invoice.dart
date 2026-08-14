import 'package:equatable/equatable.dart';

import '../../../core/database/invoice_embedding_status.dart';

enum InvoiceSourceType { camera, gallery }

class InvoiceItem extends Equatable {
  const InvoiceItem({
    this.id = 0,
    required this.name,
    this.quantity,
    this.unitPriceMinor,
    this.lineTotalMinor,
  });

  final int id;
  final String name;
  final double? quantity;
  final int? unitPriceMinor;
  final int? lineTotalMinor;

  @override
  List<Object?> get props => [
    id,
    name,
    quantity,
    unitPriceMinor,
    lineTotalMinor,
  ];
}

class Invoice extends Equatable {
  const Invoice({
    this.id = 0,
    this.merchant,
    this.purchaseDate,
    this.totalMinor,
    this.currencyCode,
    this.warrantyMonths,
    this.warrantyEndDate,
    this.invoiceNumber,
    this.rawExtractedText,
    required this.searchableText,
    required this.keywordText,
    required this.imagePath,
    this.thumbnailPath,
    required this.sourceType,
    this.embedding,
    this.embeddingModelId,
    this.embeddingDimensions,
    this.embeddingStatus = InvoiceEmbeddingStatus.pending,
    this.embeddingSchemaVersion = 0,
    this.embeddingUpdatedAt,
    this.embeddingFailureCode,
    this.embeddingAttemptId,
    required this.searchTextSchemaVersion,
    this.extractionModelId,
    required this.createdAt,
    required this.updatedAt,
    required this.reviewedAt,
    required this.items,
  });

  final int id;
  final String? merchant;
  final DateTime? purchaseDate;
  final int? totalMinor;
  final String? currencyCode;
  final int? warrantyMonths;
  final DateTime? warrantyEndDate;
  final String? invoiceNumber;
  final String? rawExtractedText;
  final String searchableText;
  final String keywordText;
  final String imagePath;
  final String? thumbnailPath;
  final InvoiceSourceType sourceType;
  final List<double>? embedding;
  final String? embeddingModelId;
  final int? embeddingDimensions;
  final InvoiceEmbeddingStatus embeddingStatus;
  final int embeddingSchemaVersion;
  final DateTime? embeddingUpdatedAt;
  final String? embeddingFailureCode;
  final String? embeddingAttemptId;
  final int searchTextSchemaVersion;
  final String? extractionModelId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime reviewedAt;
  final List<InvoiceItem> items;

  Invoice copyWith({
    int? id,
    String? merchant,
    DateTime? purchaseDate,
    int? totalMinor,
    String? currencyCode,
    int? warrantyMonths,
    DateTime? warrantyEndDate,
    String? invoiceNumber,
    String? rawExtractedText,
    String? searchableText,
    String? keywordText,
    String? imagePath,
    String? thumbnailPath,
    InvoiceSourceType? sourceType,
    List<double>? embedding,
    String? embeddingModelId,
    int? embeddingDimensions,
    InvoiceEmbeddingStatus? embeddingStatus,
    int? embeddingSchemaVersion,
    DateTime? embeddingUpdatedAt,
    String? embeddingFailureCode,
    String? embeddingAttemptId,
    int? searchTextSchemaVersion,
    String? extractionModelId,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? reviewedAt,
    List<InvoiceItem>? items,
    bool clearEmbedding = false,
  }) {
    return Invoice(
      id: id ?? this.id,
      merchant: merchant ?? this.merchant,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      totalMinor: totalMinor ?? this.totalMinor,
      currencyCode: currencyCode ?? this.currencyCode,
      warrantyMonths: warrantyMonths ?? this.warrantyMonths,
      warrantyEndDate: warrantyEndDate ?? this.warrantyEndDate,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      rawExtractedText: rawExtractedText ?? this.rawExtractedText,
      searchableText: searchableText ?? this.searchableText,
      keywordText: keywordText ?? this.keywordText,
      imagePath: imagePath ?? this.imagePath,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      sourceType: sourceType ?? this.sourceType,
      embedding: clearEmbedding ? null : embedding ?? this.embedding,
      embeddingModelId: clearEmbedding
          ? null
          : embeddingModelId ?? this.embeddingModelId,
      embeddingDimensions: clearEmbedding
          ? null
          : embeddingDimensions ?? this.embeddingDimensions,
      embeddingStatus: clearEmbedding
          ? InvoiceEmbeddingStatus.pending
          : embeddingStatus ?? this.embeddingStatus,
      embeddingSchemaVersion:
          embeddingSchemaVersion ?? this.embeddingSchemaVersion,
      embeddingUpdatedAt: clearEmbedding
          ? null
          : embeddingUpdatedAt ?? this.embeddingUpdatedAt,
      embeddingFailureCode: clearEmbedding
          ? null
          : embeddingFailureCode ?? this.embeddingFailureCode,
      embeddingAttemptId: clearEmbedding
          ? null
          : embeddingAttemptId ?? this.embeddingAttemptId,
      searchTextSchemaVersion:
          searchTextSchemaVersion ?? this.searchTextSchemaVersion,
      extractionModelId: extractionModelId ?? this.extractionModelId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      items: items ?? this.items,
    );
  }

  @override
  List<Object?> get props => [
    id,
    merchant,
    purchaseDate,
    totalMinor,
    currencyCode,
    warrantyMonths,
    warrantyEndDate,
    invoiceNumber,
    rawExtractedText,
    searchableText,
    keywordText,
    imagePath,
    thumbnailPath,
    sourceType,
    embedding,
    embeddingModelId,
    embeddingDimensions,
    embeddingStatus,
    embeddingSchemaVersion,
    embeddingUpdatedAt,
    embeddingFailureCode,
    embeddingAttemptId,
    searchTextSchemaVersion,
    extractionModelId,
    createdAt,
    updatedAt,
    reviewedAt,
    items,
  ];
}
