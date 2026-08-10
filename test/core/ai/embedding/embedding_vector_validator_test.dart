import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:wara2a/core/ai/embedding/embedding_vector_validator.dart';
import 'package:wara2a/core/ai/embedding/multilingual_e5_artifact.dart';

void main() {
  const dimensions = MultilingualE5Artifact.dimensions;

  group('normalizeAndValidate', () {
    test('returns an immutable finite 384-dimensional unit vector', () {
      final input = List<double>.filled(dimensions, 0)..setRange(0, 2, [3, 4]);

      final normalized = EmbeddingVectorValidator.normalizeAndValidate(
        input,
        dimensions: dimensions,
      );

      expect(normalized, hasLength(dimensions));
      expect(normalized[0], closeTo(0.6, 1e-12));
      expect(normalized[1], closeTo(0.8, 1e-12));
      expect(_l2Norm(normalized), closeTo(1, 1e-12));
      expect(normalized.every((value) => value.isFinite), isTrue);
      expect(() => normalized[0] = 1, throwsUnsupportedError);
    });

    test('rejects the wrong number of dimensions', () {
      expect(
        () => EmbeddingVectorValidator.normalizeAndValidate(
          List<double>.filled(dimensions - 1, 1),
          dimensions: dimensions,
        ),
        throwsA(
          isA<InvalidEmbeddingVector>().having(
            (error) => error.message,
            'message',
            'Expected 384 dimensions, got 383.',
          ),
        ),
      );
    });

    for (final invalid in <double>[
      double.nan,
      double.infinity,
      double.negativeInfinity,
    ]) {
      test('rejects non-finite component $invalid', () {
        final vector = List<double>.filled(dimensions, 0)..[0] = invalid;

        expect(
          () => EmbeddingVectorValidator.normalizeAndValidate(
            vector,
            dimensions: dimensions,
          ),
          throwsA(isA<InvalidEmbeddingVector>()),
        );
      });
    }

    test('rejects the all-zero vector', () {
      expect(
        () => EmbeddingVectorValidator.normalizeAndValidate(
          List<double>.filled(dimensions, 0),
          dimensions: dimensions,
        ),
        throwsA(
          isA<InvalidEmbeddingVector>().having(
            (error) => error.message,
            'message',
            'Embedding vector must have a finite non-zero norm.',
          ),
        ),
      );
    });
  });

  group('validateNormalized', () {
    test('accepts an exact L2-normalized vector', () {
      final unit = List<double>.filled(dimensions, 0)..[37] = -1;

      expect(
        () => EmbeddingVectorValidator.validateNormalized(
          unit,
          dimensions: dimensions,
        ),
        returnsNormally,
      );
    });

    test('rejects a finite vector whose L2 norm is not one', () {
      final notNormalized = List<double>.filled(dimensions, 0)..[0] = 0.5;

      expect(
        () => EmbeddingVectorValidator.validateNormalized(
          notNormalized,
          dimensions: dimensions,
        ),
        throwsA(
          isA<InvalidEmbeddingVector>().having(
            (error) => error.message,
            'message',
            contains('must be L2-normalized'),
          ),
        ),
      );
    });

    test('rejects overflow while accumulating otherwise finite values', () {
      final overflowing = List<double>.filled(dimensions, double.maxFinite);

      expect(
        () => EmbeddingVectorValidator.validateNormalized(
          overflowing,
          dimensions: dimensions,
        ),
        throwsA(isA<InvalidEmbeddingVector>()),
      );
    });
  });
}

double _l2Norm(Iterable<double> vector) =>
    math.sqrt(vector.fold(0, (sum, value) => sum + (value * value)));
