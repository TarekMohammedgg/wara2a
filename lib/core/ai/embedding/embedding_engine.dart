import 'dart:async';

import '../model_management/model_lifecycle_state.dart';

enum EmbeddingCapability {
  supported,
  unsupportedPlatform,
  modelAccessRequired,
  modelNotInstalled,
  ready,
  runtimeFailure,
}

class EmbeddingEngineSnapshot {
  const EmbeddingEngineSnapshot({
    required this.status,
    required this.capability,
    required this.modelId,
    this.progress,
    this.message,
  });

  final ModelLifecycleStatus status;
  final EmbeddingCapability capability;
  final String modelId;
  final double? progress;
  final String? message;

  bool get canEmbed =>
      status == ModelLifecycleStatus.ready &&
      capability == EmbeddingCapability.ready;
}

class EmbeddingOutput {
  const EmbeddingOutput({
    required this.vector,
    required this.modelId,
    required this.dimensions,
    required this.schemaVersion,
  });

  final List<double> vector;
  final String modelId;
  final int dimensions;
  final int schemaVersion;
}

abstract interface class EmbeddingEngine {
  EmbeddingEngineSnapshot get snapshot;
  Stream<EmbeddingEngineSnapshot> get snapshots;

  Future<EmbeddingEngineSnapshot> refresh();
  Future<void> install();
  Future<void> cancel();
  Future<void> unload();
  Future<EmbeddingOutput> embedDocument(String searchableText);
  Future<EmbeddingOutput> embedQuery(String normalizedQuery);
  Future<void> dispose();
}

class EmbeddingUnavailableException implements Exception {
  const EmbeddingUnavailableException(this.message);

  final String message;

  @override
  String toString() => message;
}

class EmbeddingInputTooLongException implements Exception {
  const EmbeddingInputTooLongException({
    required this.actualCharacters,
    required this.maximumCharacters,
  });

  final int actualCharacters;
  final int maximumCharacters;

  @override
  String toString() =>
      'Embedding input has $actualCharacters characters; the conservative '
      'limit is $maximumCharacters.';
}

class UnavailableEmbeddingEngine implements EmbeddingEngine {
  UnavailableEmbeddingEngine({
    required String modelId,
    String? reason,
    EmbeddingCapability capability = EmbeddingCapability.unsupportedPlatform,
    ModelLifecycleStatus status = ModelLifecycleStatus.unavailable,
  }) : _snapshot = EmbeddingEngineSnapshot(
         status: status,
         capability: capability,
         modelId: modelId,
         message: reason,
       );

  final EmbeddingEngineSnapshot _snapshot;

  @override
  EmbeddingEngineSnapshot get snapshot => _snapshot;

  @override
  Stream<EmbeddingEngineSnapshot> get snapshots => Stream.value(_snapshot);

  @override
  Future<void> cancel() async {}

  @override
  Future<void> dispose() async {}

  @override
  Future<EmbeddingOutput> embedDocument(String searchableText) => Future.error(
    EmbeddingUnavailableException(
      _snapshot.message ?? 'Embedding is unavailable.',
    ),
  );

  @override
  Future<EmbeddingOutput> embedQuery(String normalizedQuery) => Future.error(
    EmbeddingUnavailableException(
      _snapshot.message ?? 'Embedding is unavailable.',
    ),
  );

  @override
  Future<void> install() => Future.error(
    EmbeddingUnavailableException(
      _snapshot.message ?? 'Embedding is unavailable.',
    ),
  );

  @override
  Future<EmbeddingEngineSnapshot> refresh() async => _snapshot;

  @override
  Future<void> unload() async {}
}
