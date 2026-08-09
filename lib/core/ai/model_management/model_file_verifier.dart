import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';

import '../ai_cancellation_token.dart';
import 'model_manifest.dart';

enum ModelFileVerificationStatus {
  verified,
  missing,
  wrongLength,
  checksumMismatch,
  notInstallable,
}

class ModelFileVerification {
  const ModelFileVerification({
    required this.artifact,
    required this.path,
    required this.status,
    this.actualByteLength,
    this.actualSha256,
  });

  final ModelArtifactManifest artifact;
  final String path;
  final ModelFileVerificationStatus status;
  final int? actualByteLength;
  final String? actualSha256;

  bool get isVerified => status == ModelFileVerificationStatus.verified;
}

class ModelFileVerifier {
  const ModelFileVerifier();

  Future<ModelFileVerification> verify({
    required ModelArtifactManifest artifact,
    required String path,
    AiCancellationToken? cancellationToken,
  }) async {
    if (!artifact.installable) {
      return ModelFileVerification(
        artifact: artifact,
        path: path,
        status: ModelFileVerificationStatus.notInstallable,
      );
    }
    final file = File(path);
    if (!await file.exists()) {
      return ModelFileVerification(
        artifact: artifact,
        path: path,
        status: ModelFileVerificationStatus.missing,
      );
    }
    cancellationToken?.throwIfCancelled();
    final actualLength = await file.length();
    if (actualLength != artifact.byteLength) {
      return ModelFileVerification(
        artifact: artifact,
        path: path,
        status: ModelFileVerificationStatus.wrongLength,
        actualByteLength: actualLength,
      );
    }

    final digest = await sha256
        .bind(_cancellableBytes(file, cancellationToken))
        .first;
    cancellationToken?.throwIfCancelled();
    final actualSha256 = digest.toString();
    return ModelFileVerification(
      artifact: artifact,
      path: path,
      status: actualSha256 == artifact.sha256
          ? ModelFileVerificationStatus.verified
          : ModelFileVerificationStatus.checksumMismatch,
      actualByteLength: actualLength,
      actualSha256: actualSha256,
    );
  }

  Stream<List<int>> _cancellableBytes(
    File file,
    AiCancellationToken? cancellationToken,
  ) async* {
    await for (final chunk in file.openRead()) {
      cancellationToken?.throwIfCancelled();
      yield chunk;
    }
  }
}
