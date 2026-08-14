import 'dart:typed_data';
import 'dart:ui' as ui;

/// Shrinks invoice photos before OpenRouter vision calls.
///
/// Large camera JPEGs dominate upload + Gemini input tokens; a ~1280px edge
/// keeps text readable while cutting latency sharply.
class InvoiceVisionImagePreparer {
  const InvoiceVisionImagePreparer({
    this.maxSide = 1280,
    this.skipBelowBytes = 350 * 1024,
  });

  final int maxSide;
  final int skipBelowBytes;

  Future<PreparedVisionImage> prepare(
    List<int> sourceBytes, {
    required String sourceMimeType,
  }) async {
    final input = Uint8List.fromList(sourceBytes);
    if (input.lengthInBytes <= skipBelowBytes) {
      return PreparedVisionImage(bytes: input, mimeType: sourceMimeType);
    }

    try {
      final probe = await ui.instantiateImageCodec(input);
      final probeFrame = await probe.getNextFrame();
      final width = probeFrame.image.width;
      final height = probeFrame.image.height;
      probeFrame.image.dispose();
      probe.dispose();

      if (width <= maxSide && height <= maxSide) {
        return PreparedVisionImage(bytes: input, mimeType: sourceMimeType);
      }

      final targetWidth = width >= height ? maxSide : null;
      final targetHeight = height > width ? maxSide : null;
      final codec = await ui.instantiateImageCodec(
        input,
        targetWidth: targetWidth,
        targetHeight: targetHeight,
      );
      final frame = await codec.getNextFrame();
      final image = frame.image;
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      codec.dispose();
      if (byteData == null) {
        return PreparedVisionImage(bytes: input, mimeType: sourceMimeType);
      }
      final prepared = byteData.buffer.asUint8List(
        byteData.offsetInBytes,
        byteData.lengthInBytes,
      );
      // Prefer the smaller payload when PNG unexpectedly grows.
      if (prepared.lengthInBytes >= input.lengthInBytes) {
        return PreparedVisionImage(bytes: input, mimeType: sourceMimeType);
      }
      return PreparedVisionImage(bytes: prepared, mimeType: 'image/png');
    } on Object {
      return PreparedVisionImage(bytes: input, mimeType: sourceMimeType);
    }
  }
}

class PreparedVisionImage {
  const PreparedVisionImage({required this.bytes, required this.mimeType});

  final Uint8List bytes;
  final String mimeType;
}
