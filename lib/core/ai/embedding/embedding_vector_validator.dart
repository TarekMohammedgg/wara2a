import 'dart:math' as math;

class InvalidEmbeddingVector implements Exception {
  const InvalidEmbeddingVector(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract final class EmbeddingVectorValidator {
  static const normalizedTolerance = 1e-5;

  static List<double> normalizeAndValidate(
    Iterable<double> values, {
    required int dimensions,
  }) {
    final vector = List<double>.of(values, growable: false);
    if (vector.length != dimensions) {
      throw InvalidEmbeddingVector(
        'Expected $dimensions dimensions, got ${vector.length}.',
      );
    }
    var sumSquares = 0.0;
    for (final value in vector) {
      if (!value.isFinite) {
        throw const InvalidEmbeddingVector(
          'Embedding values must all be finite.',
        );
      }
      sumSquares += value * value;
    }
    final norm = math.sqrt(sumSquares);
    if (!norm.isFinite || norm <= double.minPositive) {
      throw const InvalidEmbeddingVector(
        'Embedding vector must have a finite non-zero norm.',
      );
    }
    final normalized = List<double>.unmodifiable(
      vector.map((value) => value / norm),
    );
    validateNormalized(normalized, dimensions: dimensions);
    return normalized;
  }

  static void validateNormalized(
    Iterable<double> values, {
    required int dimensions,
  }) {
    final vector = values is List<double>
        ? values
        : List<double>.of(values, growable: false);
    if (vector.length != dimensions) {
      throw InvalidEmbeddingVector(
        'Expected $dimensions dimensions, got ${vector.length}.',
      );
    }
    var sumSquares = 0.0;
    for (final value in vector) {
      if (!value.isFinite) {
        throw const InvalidEmbeddingVector(
          'Embedding values must all be finite.',
        );
      }
      sumSquares += value * value;
    }
    final norm = math.sqrt(sumSquares);
    if (!norm.isFinite || (norm - 1).abs() > normalizedTolerance) {
      throw InvalidEmbeddingVector(
        'Embedding vector must be L2-normalized; norm was $norm.',
      );
    }
  }
}
