enum ModelCapabilityStatus {
  available,
  unavailable,
  notInstalled,
  incompatibleArtifact,
  unsupportedPlatform,
}

class ModelCapability {
  const ModelCapability({
    required this.status,
    required this.runtime,
    required this.reason,
    this.platform,
    this.runtimeVersion,
    this.supportedFormats = const <String>[],
  });

  const ModelCapability.available({
    required String runtime,
    required String reason,
    String? platform,
    String? runtimeVersion,
    List<String> supportedFormats = const <String>[],
  }) : this(
         status: ModelCapabilityStatus.available,
         runtime: runtime,
         reason: reason,
         platform: platform,
         runtimeVersion: runtimeVersion,
         supportedFormats: supportedFormats,
       );

  final ModelCapabilityStatus status;
  final String runtime;
  final String reason;
  final String? platform;
  final String? runtimeVersion;
  final List<String> supportedFormats;

  bool get canInitialize => status == ModelCapabilityStatus.available;

  factory ModelCapability.fromMap(Map<Object?, Object?> map) {
    final statusName = map['status'] as String? ?? 'unavailable';
    return ModelCapability(
      status: ModelCapabilityStatus.values.firstWhere(
        (value) => value.name == statusName,
        orElse: () => ModelCapabilityStatus.unavailable,
      ),
      runtime: map['runtime'] as String? ?? 'unknown',
      reason: map['reason'] as String? ?? 'No capability reason was supplied.',
      platform: map['platform'] as String?,
      runtimeVersion: map['runtimeVersion'] as String?,
      supportedFormats:
          (map['supportedFormats'] as List<Object?>?)
              ?.whereType<String>()
              .toList(growable: false) ??
          const <String>[],
    );
  }
}
