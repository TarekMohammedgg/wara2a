import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:wara2a/core/ai/cloud/invoice_vision_image_preparer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('downscales oversized invoice photos for faster Gemini calls', () async {
    final largePng = await _solidPng(width: 2400, height: 3200);
    final prepared = await const InvoiceVisionImagePreparer(
      skipBelowBytes: 1,
    ).prepare(largePng, sourceMimeType: 'image/png');

    expect(prepared.mimeType, 'image/png');
    expect(prepared.bytes.lengthInBytes, lessThan(largePng.lengthInBytes));

    final codec = await ui.instantiateImageCodec(prepared.bytes);
    final frame = await codec.getNextFrame();
    expect(frame.image.width, lessThanOrEqualTo(1280));
    expect(frame.image.height, lessThanOrEqualTo(1280));
    frame.image.dispose();
    codec.dispose();
  });
}

Future<Uint8List> _solidPng({required int width, required int height}) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawRect(
    ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    ui.Paint()..color = const ui.Color(0xFFFFFFFF),
  );
  final image = await recorder.endRecording().toImage(width, height);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return bytes!.buffer.asUint8List();
}
