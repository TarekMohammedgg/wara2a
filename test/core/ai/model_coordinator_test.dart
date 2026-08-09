import 'package:flutter_test/flutter_test.dart';
import 'package:wara2a/core/ai/ai_cancellation_token.dart';
import 'package:wara2a/core/ai/ai_runtime_error.dart';
import 'package:wara2a/core/ai/extraction/invoice_extraction_prompt.dart';
import 'package:wara2a/core/ai/extraction/invoice_text_interpreter.dart';
import 'package:wara2a/core/ai/model_management/model_capability.dart';
import 'package:wara2a/core/ai/model_management/model_coordinator.dart';
import 'package:wara2a/core/ai/ocr/ocr_engine.dart';
import 'package:wara2a/core/ai/ocr/ocr_evidence.dart';

import 'fixture_loader.dart';

void main() {
  late OcrEvidence evidence;
  late String validOutput;
  const modelFiles = OcrModelFiles(
    detectorModelPath: 'det.onnx',
    detectorConfigPath: 'det.yml',
    arabicModelPath: 'ar.onnx',
    arabicConfigPath: 'ar.yml',
    latinModelPath: 'latin.onnx',
    latinConfigPath: 'latin.yml',
  );

  setUpAll(() async {
    evidence = await loadOcrEvidenceFixture('ocr/mixed_arabic_invoice.json');
    validOutput = await loadFixture('extraction/valid_invoice.json');
  });

  test(
    'allows exactly one repair and returns the repaired typed draft',
    () async {
      final ocr = _FakeOcrEngine(evidence);
      final interpreter = _ScriptedInterpreter(<String>[
        '{"bad":true}',
        validOutput,
      ]);
      final coordinator = ModelCoordinator(
        ocrEngineFactory: () => ocr,
        interpreterFactory: () => interpreter,
      );

      final result = await coordinator.extract(
        const InvoiceExtractionRequest(
          imagePath: 'invoice.jpg',
          ocrModels: modelFiles,
        ),
      );

      expect(interpreter.attempts, <InterpretationAttempt>[
        InterpretationAttempt.initial,
        InterpretationAttempt.repair,
      ]);
      expect(result.manualFallback, isFalse);
      expect(result.repaired, isTrue);
      expect(result.draft.totalMinor, 2499900);
      expect(ocr.disposed, isTrue);
      expect(interpreter.disposed, isTrue);
      await coordinator.dispose();
    },
  );

  test(
    'falls back to a blank review draft after the single repair fails',
    () async {
      final interpreter = _ScriptedInterpreter(<String>['{}', '{}']);
      final coordinator = ModelCoordinator(
        ocrEngineFactory: () => _FakeOcrEngine(evidence),
        interpreterFactory: () => interpreter,
      );

      final result = await coordinator.extract(
        const InvoiceExtractionRequest(
          imagePath: 'invoice.jpg',
          ocrModels: modelFiles,
        ),
      );

      expect(interpreter.attempts, hasLength(2));
      expect(result.manualFallback, isTrue);
      expect(result.error!.code, AiErrorCode.invalidModelOutput);
      expect(result.validationIssues, isNotEmpty);
      expect(result.draft.rawText, contains('Samsung Galaxy A56'));
      await coordinator.dispose();
    },
  );

  test('keeps OCR evidence when the Qwen artifact is incompatible', () async {
    final coordinator = ModelCoordinator(
      ocrEngineFactory: () => _FakeOcrEngine(evidence),
      interpreterFactory: IncompatibleQwenLiteRtInterpreter.new,
    );

    final result = await coordinator.extract(
      const InvoiceExtractionRequest(
        imagePath: 'invoice.jpg',
        ocrModels: modelFiles,
      ),
    );

    expect(result.manualFallback, isTrue);
    expect(result.error!.code, AiErrorCode.incompatibleArtifact);
    expect(result.evidence, same(evidence));
    expect(result.draft.rawText, evidence.rawText);
    await coordinator.dispose();
  });

  test('times out native OCR and requests runtime cancellation', () async {
    final ocr = _FakeOcrEngine(
      evidence,
      recognitionDelay: const Duration(seconds: 1),
    );
    final coordinator = ModelCoordinator(
      ocrEngineFactory: () => ocr,
      interpreterFactory: IncompatibleQwenLiteRtInterpreter.new,
    );

    final result = await coordinator.extract(
      const InvoiceExtractionRequest(
        imagePath: 'invoice.jpg',
        ocrModels: modelFiles,
        ocrInferenceTimeout: Duration(milliseconds: 10),
      ),
    );

    expect(result.manualFallback, isTrue);
    expect(result.error!.code, AiErrorCode.timeout);
    expect(ocr.cancelled, isTrue);
    expect(ocr.disposed, isTrue);
    await coordinator.dispose();
  });

  test('does not invoke Qwen when OCR has no trustworthy text', () async {
    final emptyEvidence = OcrEvidence(
      imageWidth: 640,
      imageHeight: 480,
      lines: const <OcrLine>[],
      timings: const OcrTimings(),
      runtime: 'fixture',
    );
    final interpreter = _ScriptedInterpreter(<String>[validOutput]);
    final coordinator = ModelCoordinator(
      ocrEngineFactory: () => _FakeOcrEngine(emptyEvidence),
      interpreterFactory: () => interpreter,
    );

    final result = await coordinator.extract(
      const InvoiceExtractionRequest(
        imagePath: 'blank.jpg',
        ocrModels: modelFiles,
      ),
    );

    expect(result.manualFallback, isTrue);
    expect(result.error!.code, AiErrorCode.invalidRuntimeResponse);
    expect(interpreter.attempts, isEmpty);
    await coordinator.dispose();
  });
}

class _FakeOcrEngine implements OcrEngine {
  _FakeOcrEngine(this.evidence, {this.recognitionDelay = Duration.zero});

  final OcrEvidence evidence;
  final Duration recognitionDelay;
  bool cancelled = false;
  bool disposed = false;

  @override
  Future<ModelCapability> capability() async => const ModelCapability.available(
    runtime: 'fixture',
    reason: 'available for deterministic tests',
  );

  @override
  Future<void> initialize(
    OcrModelFiles models, {
    AiCancellationToken? cancellationToken,
  }) async {
    cancellationToken?.throwIfCancelled();
  }

  @override
  Future<OcrEvidence> recognizeInvoice(
    String imagePath, {
    AiCancellationToken? cancellationToken,
  }) async {
    if (recognitionDelay > Duration.zero) {
      await Future<void>.delayed(recognitionDelay);
    }
    cancellationToken?.throwIfCancelled();
    return evidence;
  }

  @override
  Future<void> cancel() async {
    cancelled = true;
  }

  @override
  Future<void> dispose() async {
    disposed = true;
  }
}

class _ScriptedInterpreter implements InvoiceTextInterpreter {
  _ScriptedInterpreter(this.outputs);

  final List<String> outputs;
  final List<InterpretationAttempt> attempts = <InterpretationAttempt>[];
  bool disposed = false;

  @override
  Future<ModelCapability> capability() async => const ModelCapability.available(
    runtime: 'fixture',
    reason: 'available for deterministic tests',
  );

  @override
  Future<void> initialize({AiCancellationToken? cancellationToken}) async {
    cancellationToken?.throwIfCancelled();
  }

  @override
  Future<InvoiceInterpretationOutput> interpret(
    InvoiceInterpretationRequest request, {
    AiCancellationToken? cancellationToken,
  }) async {
    cancellationToken?.throwIfCancelled();
    attempts.add(request.attempt);
    final index = attempts.length - 1;
    return InvoiceInterpretationOutput(
      json: outputs[index],
      modelId: 'fixture',
      elapsed: Duration.zero,
    );
  }

  @override
  Future<void> cancel() async {}

  @override
  Future<void> dispose() async {
    disposed = true;
  }
}
