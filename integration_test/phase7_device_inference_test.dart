import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:wara2a/core/ai/extraction/invoice_extraction_prompt.dart';
import 'package:wara2a/core/ai/extraction/invoice_text_interpreter.dart';
import 'package:wara2a/core/ai/extraction/method_channel_qwen_interpreter.dart';
import 'package:wara2a/core/ai/model_management/bundled_model_manifest.dart';
import 'package:wara2a/core/ai/model_management/model_coordinator.dart';
import 'package:wara2a/core/ai/model_management/model_installation.dart';
import 'package:wara2a/core/ai/ocr/method_channel_ocr_engine.dart';
import 'package:wara2a/features/invoice_capture/models/invoice_draft.dart';
import 'package:wara2a/features/invoice_capture/models/invoice_image_draft.dart';
import 'package:wara2a/features/invoice_capture/models/review_route_args.dart';
import 'package:wara2a/features/invoice_capture/repositories/invoice_extraction_repository.dart';
import 'package:wara2a/features/settings/models/local_ai_status.dart';
import 'package:wara2a/features/settings/repositories/local_ai_status_repository.dart';

const bool _enabled = bool.fromEnvironment('PHASE7_DEVICE_AI_TEST');
const bool _waitForEngineeringSideload = bool.fromEnvironment(
  'PHASE7_ENGINEERING_SIDELOAD',
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'installs pinned models and runs bilingual OCR plus Qwen on device',
    (tester) async {
      if (_waitForEngineeringSideload) {
        await _awaitEngineeringSideload();
      }
      final installerWatch = Stopwatch()..start();
      final statusRepository = DeviceLocalAiStatusRepository();
      String? lastProgressKey;
      try {
        await statusRepository.installRequired((progress) {
          final key = '${progress.stage.name}:${progress.artifact?.modelId}';
          if (key == lastProgressKey) return;
          lastProgressKey = key;
          debugPrint(
            'PHASE7_INSTALL stage=${progress.stage.name} '
            'artifact=${progress.artifact?.modelId ?? '-'} '
            'completed=${progress.completedBytes} total=${progress.totalBytes}',
          );
        });
        installerWatch.stop();
        final status = await statusRepository.inspect();
        debugPrint(
          'PHASE7_INSTALL_RESULT readiness=${status.readiness.name} '
          'elapsedMs=${installerWatch.elapsedMilliseconds} '
          'verifiedBytes=${status.installedBytes} '
          'requiredBytes=${status.requiredBytes}',
        );
        expect(status.readiness, LocalAiReadiness.ready);
      } finally {
        await statusRepository.close();
      }

      final image = await _writeSyntheticBilingualInvoice();
      final extractionRepository = LocalInvoiceExtractionRepository(
        ModelCoordinator(
          ocrEngineFactory: PlatformOcrEngine.new,
          interpreterFactory: PlatformQwenTextInterpreter.new,
        ),
      );
      final extractionWatch = Stopwatch()..start();
      try {
        final result = await extractionRepository.extract(
          InvoiceImageDraft(
            id: 'phase7-physical-device-fixture',
            path: image.path,
            source: InvoiceImageSource.gallery,
            mimeType: 'image/png',
            byteLength: await image.length(),
            width: 1080,
            height: 1600,
            createdAt: DateTime.now().toUtc(),
          ),
        );
        extractionWatch.stop();
        final evidence = result.evidence;
        final arabicLines =
            evidence?.lines
                .where((line) => line.script.name == 'arabic')
                .length ??
            0;
        final latinLines =
            evidence?.lines
                .where((line) => line.script.name == 'latin')
                .length ??
            0;
        debugPrint(
          'PHASE7_INFERENCE_RESULT manual=${result.manualFallback} '
          'repaired=${result.repaired} '
          'error=${result.error?.code.name ?? '-'} '
          'stage=${result.error?.stage ?? '-'} '
          'message=${result.error?.message ?? '-'} '
          'totalElapsedMs=${extractionWatch.elapsedMilliseconds} '
          'ocrElapsedMs=${evidence?.timings.total.inMilliseconds ?? -1} '
          'qwenElapsedMs=${result.interpretationElapsed?.inMilliseconds ?? -1} '
          'inputTokens=${result.interpretationInputTokens ?? -1} '
          'ocrLines=${evidence?.lines.length ?? 0} '
          'arabicLines=$arabicLines latinLines=$latinLines '
          'model=${result.draft.extractionModelId ?? '-'} '
          'outputBytes=${result.modelOutput?.length ?? 0}',
        );
        if (result.manualFallback) {
          debugPrint(
            'PHASE7_VALIDATION_ISSUES '
            '${jsonEncode(result.validationIssues.map((issue) => issue.toPromptJson()).toList())}',
          );
        }
        if (result.manualFallback) {
          await _runDirectQwenProbe();
        }
        expect(evidence, isNotNull);
        expect(evidence!.lines, isNotEmpty);
        expect(arabicLines, greaterThan(0));
        expect(latinLines, greaterThan(0));
        expect(result.modelOutput, isNotNull);
        expect(result.manualFallback, isFalse);
        final reviewArgs = ReviewRouteArgs(draft: result.draft);
        expect(reviewArgs.draft, same(result.draft));
        expect(
          reviewArgs.draft.origin,
          isNot(InvoiceDraftOrigin.manualFallback),
        );
        expect(reviewArgs.draft.requiresManualReview, isTrue);
        expect(reviewArgs.draft.merchant, isNotNull);
        expect(reviewArgs.draft.invoiceNumber, '12345');
        expect(reviewArgs.draft.purchaseDate, DateTime.utc(2026, 8, 10));
        expect(reviewArgs.draft.totalMinor, 12550);
        expect(reviewArgs.draft.currencyCode, 'EGP');
        expect(reviewArgs.draft.products, hasLength(2));
        expect(
          reviewArgs.draft.products.map((product) => product.name),
          orderedEquals(<String>['Coffee', 'Notebook']),
        );
        expect(reviewArgs.draft.products[0].quantity, 2);
        expect(reviewArgs.draft.products[0].unitPriceMinor, 2500);
        expect(reviewArgs.draft.products[0].lineTotalMinor, 5000);
        expect(reviewArgs.draft.products[1].quantity, 1);
        expect(reviewArgs.draft.products[1].unitPriceMinor, 7550);
        expect(reviewArgs.draft.products[1].lineTotalMinor, 7550);
        expect(result.interpretationInputTokens, isNotNull);
        expect(
          result.interpretationInputTokens! + defaultInvoiceMaximumOutputTokens,
          lessThanOrEqualTo(1280),
        );
        expect(
          result.draft.extractionModelId,
          contains('Qwen2.5-0.5B-Instruct'),
        );
      } finally {
        await extractionRepository.close();
        if (await image.exists()) await image.delete();
      }
    },
    skip: !_enabled,
    timeout: const Timeout(Duration(minutes: 30)),
  );
}

Future<void> _runDirectQwenProbe() async {
  final manifest = await loadPhase7ModelManifest();
  final layout = await ModelInstallationLayout.appSupport();
  if (_waitForEngineeringSideload) {
    final waiting = File(
      '${layout.rootDirectory.path}/engineering-qwen-awaiting.ready',
    );
    final go = File('${layout.rootDirectory.path}/engineering-qwen-go.ready');
    await waiting.writeAsString('ready', flush: true);
    final timeout = Stopwatch()..start();
    while (!await go.exists()) {
      if (timeout.elapsed > const Duration(minutes: 5)) {
        throw TimeoutException('Direct Qwen measurement was not released.');
      }
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    await waiting.delete();
    await go.delete();
  }
  final interpreter = PlatformQwenTextInterpreter();
  try {
    final capability = await interpreter.capability();
    debugPrint(
      'PHASE7_DIRECT_QWEN_CAPABILITY status=${capability.status.name} '
      'runtime=${capability.runtime} version=${capability.runtimeVersion ?? '-'}',
    );
    expect(capability.canInitialize, isTrue);
    final initializeWatch = Stopwatch()..start();
    await interpreter.initialize(layout.qwenModelPath(manifest));
    initializeWatch.stop();
    final output = await interpreter.interpret(
      const InvoiceInterpretationRequest(
        prompt: '''Return one JSON object only using this exact schema:
{"merchantName":string|null,"documentType":string|null,"purchaseDate":string|null,"invoiceNumber":string|null,"totalMinor":integer|null,"currencyCode":string|null,"items":[],"warrantyMonths":integer|null}
OCR evidence:
AL NOOR MARKET
INVOICE NO: 12345
DATE: 2026-08-10
TOTAL: 125.50 EGP''',
        attempt: InterpretationAttempt.initial,
      ),
    );
    final decoded = jsonDecode(output.json);
    debugPrint(
      'PHASE7_DIRECT_QWEN_RESULT initializeMs=${initializeWatch.elapsedMilliseconds} '
      'generateMs=${output.elapsed.inMilliseconds} model=${output.modelId} '
      'outputBytes=${utf8.encode(output.json).length} jsonObject=${decoded is Map}',
    );
    expect(decoded, isA<Map<Object?, Object?>>());
  } finally {
    await interpreter.dispose();
  }
}

Future<void> _awaitEngineeringSideload() async {
  final layout = await ModelInstallationLayout.appSupport();
  await layout.rootDirectory.create(recursive: true);
  final ready = File('${layout.rootDirectory.path}/engineering-sideload.ready');
  debugPrint('PHASE7_WAITING_FOR_ENGINEERING_SIDELOAD');
  final timeout = Stopwatch()..start();
  while (!await ready.exists()) {
    if (timeout.elapsed > const Duration(minutes: 10)) {
      throw TimeoutException('Engineering sideload was not signalled.');
    }
    await Future<void>.delayed(const Duration(seconds: 1));
  }
  await ready.delete();
  debugPrint('PHASE7_ENGINEERING_SIDELOAD_READY');
}

Future<File> _writeSyntheticBilingualInvoice() async {
  const width = 1080;
  const height = 1600;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    const Rect.fromLTWH(0, 0, 1080, 1600),
    Paint()..color = Colors.white,
  );
  canvas.drawRect(
    const Rect.fromLTWH(55, 55, 970, 1490),
    Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4,
  );

  _paintLine(canvas, 'AL NOOR MARKET', 120, 100, fontSize: 62, bold: true);
  _paintLine(
    canvas,
    'متجر النور',
    120,
    190,
    fontSize: 62,
    bold: true,
    direction: TextDirection.rtl,
  );
  _paintLine(canvas, 'TAX INVOICE / فاتورة ضريبية', 120, 310, fontSize: 44);
  _paintLine(canvas, 'INVOICE NO: 12345', 120, 420, fontSize: 42);
  _paintLine(canvas, 'DATE: 2026-08-10', 120, 495, fontSize: 42);
  _paintLine(canvas, 'Coffee        2 x 25.00       50.00', 120, 650);
  _paintLine(canvas, 'Notebook      1 x 75.50       75.50', 120, 735);
  canvas.drawLine(
    const Offset(110, 870),
    const Offset(970, 870),
    Paint()
      ..color = Colors.black
      ..strokeWidth = 3,
  );
  _paintLine(canvas, 'TOTAL: 125.50 EGP', 120, 920, fontSize: 56, bold: true);
  _paintLine(
    canvas,
    'الإجمالي: ١٢٥٫٥٠ جنيه',
    120,
    1020,
    fontSize: 54,
    bold: true,
    direction: TextDirection.rtl,
  );
  _paintLine(canvas, 'Thank you / شكراً', 120, 1240, fontSize: 46);

  final picture = recorder.endRecording();
  final rendered = await picture.toImage(width, height);
  final data = await rendered.toByteData(format: ui.ImageByteFormat.png);
  rendered.dispose();
  picture.dispose();
  if (data == null) throw StateError('Unable to encode synthetic invoice.');
  final documents = await getApplicationDocumentsDirectory();
  final file = File('${documents.path}/phase7-physical-device-invoice.png');
  return file.writeAsBytes(
    Uint8List.sublistView(data.buffer.asUint8List()),
    flush: true,
  );
}

void _paintLine(
  Canvas canvas,
  String text,
  double x,
  double y, {
  double fontSize = 40,
  bool bold = false,
  TextDirection direction = TextDirection.ltr,
}) {
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        color: Colors.black,
        fontSize: fontSize,
        fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
      ),
    ),
    textDirection: direction,
  )..layout(maxWidth: 840);
  painter.paint(canvas, Offset(x, y));
}
