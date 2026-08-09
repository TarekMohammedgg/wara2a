enum InvoiceEmbeddingStatus { pending, indexing, ready, failed, unavailable }

extension InvoiceEmbeddingStatusStorage on InvoiceEmbeddingStatus {
  String get storageValue => name;
}

InvoiceEmbeddingStatus invoiceEmbeddingStatusFromStorage(String? value) {
  return InvoiceEmbeddingStatus.values.firstWhere(
    (status) => status.name == value,
    orElse: () => InvoiceEmbeddingStatus.pending,
  );
}
