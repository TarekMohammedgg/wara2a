import 'entities/invoice_entity.dart';
import 'entities/invoice_item_entity.dart';
import 'invoice_embedding_status.dart';

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

class InvoiceEmbeddingCommit {
  const InvoiceEmbeddingCommit({
    required this.invoiceId,
    required this.expectedSearchableText,
    required this.expectedSearchTextSchemaVersion,
    required this.expectedAttemptId,
    required this.vector,
    required this.modelId,
    required this.dimensions,
    required this.embeddingSchemaVersion,
    required this.indexedAt,
  });

  final int invoiceId;
  final String expectedSearchableText;
  final int expectedSearchTextSchemaVersion;
  final String expectedAttemptId;
  final List<double> vector;
  final String modelId;
  final int dimensions;
  final int embeddingSchemaVersion;
  final DateTime indexedAt;
}

class InvoiceEmbeddingStatusUpdate {
  const InvoiceEmbeddingStatusUpdate({
    required this.invoiceId,
    required this.status,
    this.expectedSearchableText,
    this.expectedSearchTextSchemaVersion,
    this.expectedCurrentStatus,
    this.attemptId,
    this.expectedAttemptId,
    this.failureCode,
  });

  final int invoiceId;
  final InvoiceEmbeddingStatus status;
  final String? expectedSearchableText;
  final int? expectedSearchTextSchemaVersion;
  final InvoiceEmbeddingStatus? expectedCurrentStatus;
  final String? attemptId;
  final String? expectedAttemptId;
  final String? failureCode;
}
