import 'dart:convert';

enum ModelArtifactFormat {
  onnx,
  yaml,
  liteRtLm,
  mediaPipeTask,
  tflite,
  sentencePiece,
}

class ModelArtifactManifest {
  const ModelArtifactManifest({
    required this.modelId,
    required this.displayName,
    required this.runtime,
    required this.fileName,
    required this.revision,
    required this.byteLength,
    required this.sha256,
    required this.minimumAppVersion,
    required this.capabilities,
    required this.format,
    required this.sourceUri,
    required this.license,
    required this.installable,
  });

  final String modelId;
  final String displayName;
  final String runtime;
  final String fileName;
  final String revision;
  final int byteLength;
  final String sha256;
  final String minimumAppVersion;
  final List<String> capabilities;
  final ModelArtifactFormat format;
  final Uri sourceUri;
  final String license;
  final bool installable;

  factory ModelArtifactManifest.fromJson(Map<String, Object?> json) {
    T requireValue<T>(String key) {
      final value = json[key];
      if (value is! T) {
        throw FormatException('Manifest field "$key" must be $T.');
      }
      return value;
    }

    final sha256 = requireValue<String>('sha256').toLowerCase();
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(sha256)) {
      throw const FormatException(
        'Manifest sha256 must contain 64 hex digits.',
      );
    }
    final byteLength = requireValue<int>('byteLength');
    if (byteLength <= 0) {
      throw const FormatException('Manifest byteLength must be positive.');
    }
    final formatName = requireValue<String>('format');
    final format = ModelArtifactFormat.values.firstWhere(
      (value) => value.name == formatName,
      orElse: () => throw FormatException(
        'Unsupported model artifact format "$formatName".',
      ),
    );
    final sourceUri = Uri.parse(requireValue<String>('sourceUri'));
    if (!sourceUri.isScheme('https')) {
      throw const FormatException('Model sourceUri must use HTTPS.');
    }

    return ModelArtifactManifest(
      modelId: requireValue<String>('modelId'),
      displayName: requireValue<String>('displayName'),
      runtime: requireValue<String>('runtime'),
      fileName: requireValue<String>('fileName'),
      revision: requireValue<String>('revision'),
      byteLength: byteLength,
      sha256: sha256,
      minimumAppVersion: requireValue<String>('minimumAppVersion'),
      capabilities: requireValue<List<Object?>>(
        'capabilities',
      ).whereType<String>().toList(growable: false),
      format: format,
      sourceUri: sourceUri,
      license: requireValue<String>('license'),
      installable: requireValue<bool>('installable'),
    );
  }
}

class Phase7ModelManifest {
  const Phase7ModelManifest({
    required this.schemaVersion,
    required this.researchedAt,
    required this.artifacts,
  });

  final int schemaVersion;
  final DateTime researchedAt;
  final List<ModelArtifactManifest> artifacts;

  factory Phase7ModelManifest.parse(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('The model manifest root must be an object.');
    }
    final schemaVersion = decoded['schemaVersion'];
    final researchedAt = decoded['researchedAt'];
    final artifacts = decoded['artifacts'];
    if (schemaVersion is! int ||
        researchedAt is! String ||
        artifacts is! List) {
      throw const FormatException('The model manifest root is incomplete.');
    }
    final parsedArtifacts = artifacts
        .map((entry) {
          if (entry is! Map<String, Object?>) {
            throw const FormatException(
              'Every model artifact must be an object.',
            );
          }
          return ModelArtifactManifest.fromJson(entry);
        })
        .toList(growable: false);
    final ids = parsedArtifacts.map((artifact) => artifact.modelId).toSet();
    if (ids.length != parsedArtifacts.length) {
      throw const FormatException('Model manifest IDs must be unique.');
    }
    return Phase7ModelManifest(
      schemaVersion: schemaVersion,
      researchedAt: DateTime.parse(researchedAt).toUtc(),
      artifacts: parsedArtifacts,
    );
  }

  ModelArtifactManifest byId(String modelId) => artifacts.firstWhere(
    (artifact) => artifact.modelId == modelId,
    orElse: () => throw StateError('Unknown model artifact "$modelId".'),
  );
}
