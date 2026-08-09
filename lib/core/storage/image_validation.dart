import 'dart:ui' as ui;

import 'package:image_picker/image_picker.dart';

enum CaptureImageFailureType {
  unsupportedFormat,
  tooLarge,
  invalidDimensions,
  corrupted,
  picker,
  recovery,
}

class CaptureImageException implements Exception {
  const CaptureImageException(this.type, this.message);

  final CaptureImageFailureType type;
  final String message;

  @override
  String toString() => message;
}

class ValidatedImageFile {
  const ValidatedImageFile({
    required this.extension,
    required this.mimeType,
    required this.byteLength,
    required this.width,
    required this.height,
  });

  final String extension;
  final String mimeType;
  final int byteLength;
  final int width;
  final int height;
}

class ImageFileValidator {
  const ImageFileValidator();

  static const maximumBytes = 15 * 1024 * 1024;
  static const minimumDimension = 320;
  static const maximumDimension = 4096;
  static const maximumPixels = 20 * 1024 * 1024;

  static const _mimeTypes = <String, String>{
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
    'webp': 'image/webp',
  };

  Future<ValidatedImageFile> validate(XFile file) async {
    final extension = _extensionOf(file.name);
    final expectedMimeType = _mimeTypes[extension];
    final suppliedMimeType = _normalizeMimeType(file.mimeType);
    if (expectedMimeType == null ||
        (suppliedMimeType != null && suppliedMimeType != expectedMimeType)) {
      throw const CaptureImageException(
        CaptureImageFailureType.unsupportedFormat,
        'Choose a JPEG, PNG, or WebP invoice image.',
      );
    }

    final byteLength = await file.length();
    if (byteLength > maximumBytes) {
      throw const CaptureImageException(
        CaptureImageFailureType.tooLarge,
        'Choose an image smaller than 15 MB.',
      );
    }
    if (byteLength == 0) {
      throw const CaptureImageException(
        CaptureImageFailureType.corrupted,
        'This image file is empty or damaged. Choose another image.',
      );
    }

    try {
      final bytes = await file.readAsBytes();
      if (_mimeTypeFromHeader(bytes) != expectedMimeType) {
        throw const CaptureImageException(
          CaptureImageFailureType.unsupportedFormat,
          'Choose a JPEG, PNG, or WebP invoice image.',
        );
      }
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final width = frame.image.width;
      final height = frame.image.height;
      frame.image.dispose();
      codec.dispose();

      if (width < minimumDimension ||
          height < minimumDimension ||
          width > maximumDimension ||
          height > maximumDimension ||
          width * height > maximumPixels) {
        throw const CaptureImageException(
          CaptureImageFailureType.invalidDimensions,
          'Choose a clear invoice image between 320 px and 4096 px.',
        );
      }

      return ValidatedImageFile(
        extension: extension,
        mimeType: expectedMimeType,
        byteLength: byteLength,
        width: width,
        height: height,
      );
    } on CaptureImageException {
      rethrow;
    } catch (_) {
      throw const CaptureImageException(
        CaptureImageFailureType.corrupted,
        'This image could not be opened. Choose another image.',
      );
    }
  }

  String _extensionOf(String name) {
    final dot = name.lastIndexOf('.');
    return dot == -1 ? '' : name.substring(dot + 1).toLowerCase();
  }

  String? _normalizeMimeType(String? value) {
    final mimeType = value?.toLowerCase();
    return mimeType == 'image/jpg' ? 'image/jpeg' : mimeType;
  }

  String? _mimeTypeFromHeader(List<int> bytes) {
    if (bytes.length >= 3 &&
        bytes[0] == 0xff &&
        bytes[1] == 0xd8 &&
        bytes[2] == 0xff) {
      return 'image/jpeg';
    }
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4e &&
        bytes[3] == 0x47 &&
        bytes[4] == 0x0d &&
        bytes[5] == 0x0a &&
        bytes[6] == 0x1a &&
        bytes[7] == 0x0a) {
      return 'image/png';
    }
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return 'image/webp';
    }
    return null;
  }
}
