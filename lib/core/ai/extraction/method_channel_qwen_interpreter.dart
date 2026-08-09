import 'dart:io';

import 'package:flutter/services.dart';

import '../ai_cancellation_token.dart';
import '../ai_runtime_error.dart';
import '../model_management/model_capability.dart';
import 'invoice_text_interpreter.dart';

class PlatformQwenTextInterpreter implements InvoiceTextInterpreter {
  PlatformQwenTextInterpreter({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(_channelName);

  static const String _channelName = 'com.wara2a.ai/qwen';
  static const String _systemPrompt =
      'You are a deterministic invoice extraction engine. Follow the user '
      'schema exactly, use only supplied OCR evidence, and return JSON only.';

  final MethodChannel _channel;
  bool _disposed = false;

  @override
  Future<ModelCapability> capability() async {
    if (!Platform.isAndroid) {
      return ModelCapability(
        status: ModelCapabilityStatus.unsupportedPlatform,
        runtime: 'MediaPipe LLM Inference',
        platform: Platform.operatingSystem,
        reason:
            'The Qwen runtime is Android-only until signed iOS device qualification is completed.',
        supportedFormats: const <String>['task'],
      );
    }
    try {
      final value = await _channel.invokeMethod<Object?>('capability');
      if (value is! Map<Object?, Object?>) {
        throw const FormatException(
          'The Qwen capability response must be an object.',
        );
      }
      return ModelCapability.fromMap(value);
    } on MissingPluginException catch (error) {
      return ModelCapability(
        status: ModelCapabilityStatus.unavailable,
        runtime: 'MediaPipe LLM Inference',
        platform: 'android',
        reason: 'The Android Qwen bridge is not registered: $error',
        supportedFormats: const <String>['task'],
      );
    }
  }

  @override
  Future<void> initialize(
    String modelPath, {
    AiCancellationToken? cancellationToken,
  }) async {
    _ensureNotDisposed();
    cancellationToken?.throwIfCancelled();
    await _invoke<void>('initialize', <String, String>{'modelPath': modelPath});
    cancellationToken?.throwIfCancelled();
  }

  @override
  Future<InvoiceInterpretationOutput> interpret(
    InvoiceInterpretationRequest request, {
    AiCancellationToken? cancellationToken,
  }) async {
    _ensureNotDisposed();
    cancellationToken?.throwIfCancelled();
    final response = await _invoke<Object?>('interpret', <String, Object?>{
      'prompt': _formatPrompt(request.prompt),
      'maximumOutputTokens': request.maximumOutputTokens,
    });
    cancellationToken?.throwIfCancelled();
    if (response is! Map<Object?, Object?>) {
      throw const AiRuntimeException(
        code: AiErrorCode.invalidRuntimeResponse,
        stage: 'interpreter',
        message: 'The native Qwen bridge returned a non-object response.',
      );
    }
    final text = response['text'];
    final modelId = response['modelId'];
    final elapsedMs = response['elapsedMs'];
    if (text is! String ||
        text.trim().isEmpty ||
        modelId is! String ||
        elapsedMs is! int ||
        elapsedMs < 0) {
      throw const AiRuntimeException(
        code: AiErrorCode.invalidRuntimeResponse,
        stage: 'interpreter',
        message: 'The native Qwen response has invalid metadata.',
      );
    }
    return InvoiceInterpretationOutput(
      json: text.trim(),
      modelId: modelId,
      elapsed: Duration(milliseconds: elapsedMs),
    );
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

  String _formatPrompt(String userPrompt) =>
      '<|im_start|>system\n$_systemPrompt<|im_end|>\n'
      '<|im_start|>user\n$userPrompt<|im_end|>\n'
      '<|im_start|>assistant\n';

  Future<T?> _invoke<T>(String method, [Object? arguments]) async {
    try {
      return await _channel.invokeMethod<T>(method, arguments);
    } on PlatformException catch (error) {
      throw AiRuntimeException(
        code: _errorCode(error.code),
        stage: 'interpreter',
        message: error.message ?? 'The native Qwen runtime failed.',
        cause: error,
      );
    } on MissingPluginException catch (error) {
      throw AiRuntimeException(
        code: AiErrorCode.unsupportedPlatform,
        stage: 'interpreter',
        message: 'The Qwen bridge is unavailable on this platform.',
        cause: error,
      );
    }
  }

  AiErrorCode _errorCode(String nativeCode) => switch (nativeCode) {
    'model_not_installed' => AiErrorCode.modelNotInstalled,
    'prompt_too_long' => AiErrorCode.invalidRuntimeResponse,
    'invalid_runtime_response' => AiErrorCode.invalidRuntimeResponse,
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
        stage: 'interpreter',
        message: 'The Qwen interpreter has already been disposed.',
        recoverable: false,
      );
    }
  }
}
