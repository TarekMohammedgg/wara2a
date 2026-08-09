import 'dart:io';

import 'package:flutter/services.dart';

import '../ai_cancellation_token.dart';
import '../ai_runtime_error.dart';
import '../model_management/model_capability.dart';
import 'ocr_engine.dart';
import 'ocr_evidence.dart';

class PlatformOcrEngine implements OcrEngine {
  PlatformOcrEngine({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(_channelName);

  static const String _channelName = 'com.wara2a.ai/ocr';
  final MethodChannel _channel;
  bool _disposed = false;

  @override
  Future<ModelCapability> capability() async {
    if (!Platform.isAndroid) {
      return ModelCapability(
        status: ModelCapabilityStatus.unsupportedPlatform,
        runtime: 'PaddleOCR PP-OCRv5 / ONNX Runtime',
        platform: Platform.operatingSystem,
        reason:
            'The iOS OCR runtime is intentionally capability-gated until a signed physical-device spike is verified.',
        supportedFormats: const <String>['onnx'],
      );
    }
    try {
      final result = await _channel.invokeMethod<Object?>('capability');
      if (result is! Map<Object?, Object?>) {
        throw const FormatException(
          'The OCR capability response must be an object.',
        );
      }
      return ModelCapability.fromMap(result);
    } on MissingPluginException catch (error) {
      return ModelCapability(
        status: ModelCapabilityStatus.unavailable,
        runtime: 'PaddleOCR PP-OCRv5 / ONNX Runtime',
        platform: 'android',
        reason: 'The Android OCR bridge is not registered: $error',
        supportedFormats: const <String>['onnx'],
      );
    }
  }

  @override
  Future<void> initialize(
    OcrModelFiles models, {
    AiCancellationToken? cancellationToken,
  }) async {
    _ensureNotDisposed();
    cancellationToken?.throwIfCancelled();
    await _invoke<void>('initialize', models.toMap());
    cancellationToken?.throwIfCancelled();
  }

  @override
  Future<OcrEvidence> recognizeInvoice(
    String imagePath, {
    AiCancellationToken? cancellationToken,
  }) async {
    _ensureNotDisposed();
    cancellationToken?.throwIfCancelled();
    final result = await _invoke<Object?>('recognizeInvoice', <String, Object?>{
      'imagePath': imagePath,
    });
    cancellationToken?.throwIfCancelled();
    if (result is! Map<Object?, Object?>) {
      throw const AiRuntimeException(
        code: AiErrorCode.invalidRuntimeResponse,
        stage: 'ocr',
        message: 'The native OCR bridge returned a non-object response.',
      );
    }
    try {
      return OcrEvidence.fromMap(result);
    } on Object catch (error) {
      throw AiRuntimeException(
        code: AiErrorCode.invalidRuntimeResponse,
        stage: 'ocr',
        message: error is FormatException
            ? error.message
            : 'The native OCR response contains an invalid field type.',
        cause: error,
      );
    }
  }

  @override
  Future<void> cancel() async {
    if (_disposed || !Platform.isAndroid) return;
    await _invoke<void>('cancel');
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    if (Platform.isAndroid) await _invoke<void>('dispose');
  }

  Future<T?> _invoke<T>(String method, [Object? arguments]) async {
    try {
      return await _channel.invokeMethod<T>(method, arguments);
    } on PlatformException catch (error) {
      throw AiRuntimeException(
        code: _errorCode(error.code),
        stage: 'ocr',
        message: error.message ?? 'The native OCR runtime failed.',
        cause: error,
      );
    } on MissingPluginException catch (error) {
      throw AiRuntimeException(
        code: AiErrorCode.unsupportedPlatform,
        stage: 'ocr',
        message: 'The OCR bridge is unavailable on this platform.',
        cause: error,
      );
    }
  }

  AiErrorCode _errorCode(String nativeCode) => switch (nativeCode) {
    'model_not_installed' => AiErrorCode.modelNotInstalled,
    'invalid_image' => AiErrorCode.invalidImage,
    'cancelled' => AiErrorCode.cancelled,
    'disposed' => AiErrorCode.disposed,
    'busy' => AiErrorCode.busy,
    'initialization_failed' => AiErrorCode.initializationFailed,
    _ => AiErrorCode.inferenceFailed,
  };

  void _ensureNotDisposed() {
    if (_disposed) {
      throw const AiRuntimeException(
        code: AiErrorCode.disposed,
        stage: 'ocr',
        message: 'The OCR engine has already been disposed.',
        recoverable: false,
      );
    }
  }
}
