import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:wara2a/core/storage/image_validation.dart';

void main() {
  late Directory temporaryDirectory;
  const validator = ImageFileValidator();

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'wara2a-image-test-',
    );
  });

  tearDown(() async {
    if (await temporaryDirectory.exists()) {
      await temporaryDirectory.delete(recursive: true);
    }
  });

  test('rejects an unsupported extension before decoding', () async {
    final file = File(
      '${temporaryDirectory.path}${Platform.pathSeparator}invoice.gif',
    );
    await file.writeAsBytes([0x47, 0x49, 0x46, 0x38]);

    await expectLater(
      validator.validate(XFile(file.path, mimeType: 'image/gif')),
      throwsA(
        isA<CaptureImageException>().having(
          (error) => error.type,
          'type',
          CaptureImageFailureType.unsupportedFormat,
        ),
      ),
    );
  });

  test('rejects corrupt bytes that claim to be a JPEG', () async {
    final file = File(
      '${temporaryDirectory.path}${Platform.pathSeparator}invoice.jpg',
    );
    await file.writeAsBytes([0x00, 0x01, 0x02, 0x03]);

    await expectLater(
      validator.validate(XFile(file.path, mimeType: 'image/jpeg')),
      throwsA(
        isA<CaptureImageException>().having(
          (error) => error.type,
          'type',
          CaptureImageFailureType.unsupportedFormat,
        ),
      ),
    );
  });

  test('rejects a file that exceeds the draft size limit', () async {
    final file = File(
      '${temporaryDirectory.path}${Platform.pathSeparator}invoice.jpg',
    );
    await file.writeAsBytes(
      List<int>.filled(ImageFileValidator.maximumBytes + 1, 0),
    );

    await expectLater(
      validator.validate(XFile(file.path, mimeType: 'image/jpeg')),
      throwsA(
        isA<CaptureImageException>().having(
          (error) => error.type,
          'type',
          CaptureImageFailureType.tooLarge,
        ),
      ),
    );
  });
}
