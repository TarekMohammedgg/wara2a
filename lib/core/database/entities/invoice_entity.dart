import 'package:objectbox/objectbox.dart';

@Entity()
class InvoiceEntity {
  InvoiceEntity({
    this.id = 0,
    this.merchant,
    this.merchantNormalized,
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
    this.legacyEmbedding768,
    this.legacyEmbedding384,
    this.embedding,
    this.embeddingModelId,
    this.embeddingDimensions,
    this.embeddingStatus = 'pending',
    this.embeddingSchemaVersion = 0,
    this.embeddingUpdatedAt,
    this.embeddingFailureCode,
    this.embeddingAttemptId,
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

  @Property(type: PropertyType.date)
  @Index()
  DateTime? purchaseDate;

  @Index()
  int? totalMinor;

  @Index()
  String? currencyCode;
  int? warrantyMonths;

  @Property(type: PropertyType.date)
  @Index()
  DateTime? warrantyEndDate;

  @Index()
  String? invoiceNumber;

  String? rawExtractedText;
  String searchableText;
  String keywordText;
  String imagePath;
  String? thumbnailPath;
  String sourceType;

  // Keep retired HNSW properties and UIDs forever; dimensions are immutable.
  @Property(type: PropertyType.floatVector, uid: 3475944700035130751)
  @HnswIndex(dimensions: 768, distanceType: VectorDistanceType.cosine)
  List<double>? legacyEmbedding768;

  @Property(type: PropertyType.floatVector, uid: 5286991857557893889)
  @HnswIndex(dimensions: 384, distanceType: VectorDistanceType.cosine)
  List<double>? legacyEmbedding384;

  /// Active cloud embedding index (`openai/text-embedding-3-small`, 1536-d).
  @Property(type: PropertyType.floatVector)
  @HnswIndex(dimensions: 1536, distanceType: VectorDistanceType.cosine)
  List<double>? embedding;

  String? embeddingModelId;
  int? embeddingDimensions;

  @Index()
  String embeddingStatus;

  @Index()
  int embeddingSchemaVersion;

  @Property(type: PropertyType.date)
  DateTime? embeddingUpdatedAt;

  String? embeddingFailureCode;

  String? embeddingAttemptId;

  @Index()
  int searchTextSchemaVersion;
  String? extractionModelId;

  @Property(type: PropertyType.date)
  DateTime createdAt;

  @Property(type: PropertyType.date)
  DateTime updatedAt;

  @Property(type: PropertyType.date)
  DateTime reviewedAt;
}
