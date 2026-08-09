import 'package:objectbox/objectbox.dart';

@Entity()
class InvoiceEntity {
  InvoiceEntity({
    this.id = 0,
    this.merchant,
    this.merchantNormalized,
    this.documentType,
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
    required this.searchTextSchemaVersion,
    this.extractionModelId,
    required this.createdAt,
    required this.updatedAt,
    required this.reviewedAt,
  });

  @Id()
  int id;

  String? merchant;

  @Index()
  String? merchantNormalized;

  @Index()
  String? documentType;

  @Property(type: PropertyType.date)
  DateTime? purchaseDate;

  int? totalMinor;
  String? currencyCode;
  int? warrantyMonths;

  @Property(type: PropertyType.date)
  DateTime? warrantyEndDate;

  @Index()
  String? invoiceNumber;

  String? rawExtractedText;
  String searchableText;
  String keywordText;
  String imagePath;
  String? thumbnailPath;
  String sourceType;

  @Property(type: PropertyType.floatVector)
  @HnswIndex(dimensions: 768, distanceType: VectorDistanceType.cosine)
  List<double>? embedding;

  String? embeddingModelId;
  int? embeddingDimensions;
  int searchTextSchemaVersion;
  String? extractionModelId;

  @Property(type: PropertyType.date)
  DateTime createdAt;

  @Property(type: PropertyType.date)
  DateTime updatedAt;

  @Property(type: PropertyType.date)
  DateTime reviewedAt;
}
