import 'dart:math' as math;

enum OcrScript { arabic, latin, numeric, mixed, unknown }

class OcrPoint {
  const OcrPoint(this.x, this.y);

  final double x;
  final double y;

  factory OcrPoint.fromMap(Map<Object?, Object?> map) {
    final x = map['x'];
    final y = map['y'];
    if (x is! num || y is! num || !x.isFinite || !y.isFinite) {
      throw const FormatException(
        'OCR point coordinates must be finite numbers.',
      );
    }
    return OcrPoint(x.toDouble(), y.toDouble());
  }
}

class OcrQuadrilateral {
  OcrQuadrilateral(Iterable<OcrPoint> points)
    : points = List.unmodifiable(points) {
    if (this.points.length != 4) {
      throw const FormatException(
        'An OCR box must contain exactly four points.',
      );
    }
  }

  final List<OcrPoint> points;

  double get minX => points.map((point) => point.x).reduce(math.min);
  double get maxX => points.map((point) => point.x).reduce(math.max);
  double get minY => points.map((point) => point.y).reduce(math.min);
  double get maxY => points.map((point) => point.y).reduce(math.max);

  factory OcrQuadrilateral.fromList(List<Object?> value) {
    return OcrQuadrilateral(
      value.map((point) {
        if (point is! Map<Object?, Object?>) {
          throw const FormatException('Each OCR box point must be an object.');
        }
        return OcrPoint.fromMap(point);
      }),
    );
  }
}

class OcrLine {
  const OcrLine({
    required this.order,
    required this.text,
    required this.box,
    required this.script,
    required this.confidence,
    required this.recognizer,
  });

  final int order;
  final String text;
  final OcrQuadrilateral box;
  final OcrScript script;
  final double confidence;
  final String recognizer;

  factory OcrLine.fromMap(Map<Object?, Object?> map) {
    final order = map['order'];
    final text = map['text'];
    final points = map['box'];
    final confidence = map['confidence'];
    final recognizer = map['recognizer'];
    if (order is! int || order < 0) {
      throw const FormatException(
        'OCR line order must be a non-negative integer.',
      );
    }
    if (text is! String || text.trim().isEmpty) {
      throw const FormatException('OCR line text must not be empty.');
    }
    if (points is! List<Object?>) {
      throw const FormatException('OCR line box must be a list.');
    }
    if (confidence is! num ||
        !confidence.isFinite ||
        confidence < 0 ||
        confidence > 1) {
      throw const FormatException(
        'OCR confidence must be between zero and one.',
      );
    }
    final reportedScript = map['script'] as String?;
    final script = OcrScript.values.firstWhere(
      (value) => value.name == reportedScript,
      orElse: () => OcrScriptDetector.classify(text),
    );
    return OcrLine(
      order: order,
      text: text,
      box: OcrQuadrilateral.fromList(points),
      script: script,
      confidence: confidence.toDouble(),
      recognizer: recognizer is String ? recognizer : 'unknown',
    );
  }
}

class OcrTimings {
  const OcrTimings({
    this.detection = Duration.zero,
    this.arabicRecognition = Duration.zero,
    this.latinRecognition = Duration.zero,
    this.total = Duration.zero,
  });

  final Duration detection;
  final Duration arabicRecognition;
  final Duration latinRecognition;
  final Duration total;

  factory OcrTimings.fromMap(Map<Object?, Object?>? map) {
    int milliseconds(String key) {
      final value = map?[key];
      return value is int && value >= 0 ? value : 0;
    }

    return OcrTimings(
      detection: Duration(milliseconds: milliseconds('detectionMs')),
      arabicRecognition: Duration(
        milliseconds: milliseconds('arabicRecognitionMs'),
      ),
      latinRecognition: Duration(
        milliseconds: milliseconds('latinRecognitionMs'),
      ),
      total: Duration(milliseconds: milliseconds('totalMs')),
    );
  }
}

class OcrEvidence {
  OcrEvidence({
    required this.imageWidth,
    required this.imageHeight,
    required Iterable<OcrLine> lines,
    required this.timings,
    required this.runtime,
  }) : lines = List.unmodifiable(
         lines.toList()..sort((a, b) => a.order.compareTo(b.order)),
       ) {
    if (imageWidth <= 0 || imageHeight <= 0) {
      throw const FormatException(
        'OCR evidence image dimensions must be positive.',
      );
    }
    final orders = this.lines.map((line) => line.order).toSet();
    if (orders.length != this.lines.length) {
      throw const FormatException('OCR line order values must be unique.');
    }
  }

  final int imageWidth;
  final int imageHeight;
  final List<OcrLine> lines;
  final OcrTimings timings;
  final String runtime;

  String get rawText => lines.map((line) => line.text).join('\n');

  factory OcrEvidence.fromMap(Map<Object?, Object?> map) {
    final width = map['imageWidth'];
    final height = map['imageHeight'];
    final rawLines = map['lines'];
    if (width is! int || height is! int || rawLines is! List<Object?>) {
      throw const FormatException('Native OCR evidence is incomplete.');
    }
    return OcrEvidence(
      imageWidth: width,
      imageHeight: height,
      lines: rawLines.map((line) {
        if (line is! Map<Object?, Object?>) {
          throw const FormatException('Native OCR lines must be objects.');
        }
        return OcrLine.fromMap(line);
      }),
      timings: OcrTimings.fromMap(map['timings'] as Map<Object?, Object?>?),
      runtime: map['runtime'] as String? ?? 'unknown',
    );
  }
}

class OcrScriptDetector {
  const OcrScriptDetector._();

  static final RegExp _arabic = RegExp(
    r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF]',
  );
  static final RegExp _latin = RegExp(r'[A-Za-z]');
  static final RegExp _digit = RegExp(r'[0-9\u0660-\u0669\u06F0-\u06F9]');

  static OcrScript classify(String text) {
    var arabic = 0;
    var latin = 0;
    var digits = 0;
    for (final rune in text.runes) {
      final character = String.fromCharCode(rune);
      if (_digit.hasMatch(character)) {
        digits++;
      } else if (_arabic.hasMatch(character)) {
        arabic++;
      } else if (_latin.hasMatch(character)) {
        latin++;
      }
    }
    if (arabic > 0 && latin > 0) return OcrScript.mixed;
    if (arabic > 0) return OcrScript.arabic;
    if (latin > 0) return OcrScript.latin;
    if (digits > 0) return OcrScript.numeric;
    return OcrScript.unknown;
  }
}
