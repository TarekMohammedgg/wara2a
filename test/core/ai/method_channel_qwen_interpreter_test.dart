import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wara2a/core/ai/extraction/invoice_extraction_prompt.dart';
import 'package:wara2a/core/ai/extraction/invoice_text_interpreter.dart';
import 'package:wara2a/core/ai/extraction/method_channel_qwen_interpreter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('uses the pinned Qwen chat template and strict output budget', () async {
    const channel = MethodChannel('test.wara2a/qwen');
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return switch (call.method) {
            'initialize' => null,
            'interpret' => <String, Object?>{
              'text': '{"merchantName":"متجر"}',
              'modelId': 'qwen-device-fixture',
              'elapsedMs': 1234,
              'inputTokens': 321,
            },
            'dispose' => null,
            _ => throw PlatformException(code: 'unexpected_method'),
          };
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });
    final interpreter = PlatformQwenTextInterpreter(channel: channel);

    await interpreter.initialize('/verified/model.task');
    final output = await interpreter.interpret(
      const InvoiceInterpretationRequest(
        prompt: 'Return the invoice JSON.',
        attempt: InterpretationAttempt.initial,
      ),
    );
    await interpreter.dispose();

    expect(calls.first.method, 'initialize');
    expect(calls.first.arguments, <String, String>{
      'modelPath': '/verified/model.task',
    });
    final arguments = calls[1].arguments as Map<Object?, Object?>;
    expect(arguments['maximumOutputTokens'], defaultInvoiceMaximumOutputTokens);
    expect(
      arguments['prompt'],
      '<|im_start|>system\n'
      'You are a deterministic invoice extraction engine. Follow the user '
      'schema exactly, use only supplied OCR evidence, and return JSON only.'
      '<|im_end|>\n'
      '<|im_start|>user\nReturn the invoice JSON.<|im_end|>\n'
      '<|im_start|>assistant\n',
    );
    expect(output.modelId, 'qwen-device-fixture');
    expect(output.elapsed, const Duration(milliseconds: 1234));
    expect(output.inputTokens, 321);
  });
}
