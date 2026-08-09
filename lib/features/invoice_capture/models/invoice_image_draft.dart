enum InvoiceImageSource { camera, gallery }

class InvoiceImageDraft {
  const InvoiceImageDraft({
    required this.id,
    required this.path,
    required this.source,
    required this.mimeType,
    required this.byteLength,
    required this.width,
    required this.height,
    required this.createdAt,
  });

  final String id;
  final String path;
  final InvoiceImageSource source;
  final String mimeType;
  final int byteLength;
  final int width;
  final int height;
  final DateTime createdAt;
}
