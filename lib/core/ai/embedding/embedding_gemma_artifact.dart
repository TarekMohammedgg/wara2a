import '../model_management/model_manifest.dart';

abstract final class EmbeddingGemmaArtifact {
  static const modelFamily = 'google/embeddinggemma-300M';
  static const repository = 'litert-community/embeddinggemma-300m';
  static const modelFileName =
      'embeddinggemma-300M_seq256_mixed-precision.tflite';
  static const tokenizerFileName = 'sentencepiece.model';
  static const modelByteLength = 179131736;
  static const tokenizerByteLength = 4683319;
  static const modelSha256 =
      '37115ef7bff76cd37dd86abe503ff511b1032bf85fc624a85c49c84899e92bc5';
  static const tokenizerSha256 =
      'd6daa52d93d7aad10e8388bd526c4e501d914b47177398d1d9621f1fe48438c7';
  static const dimensions = 768;
  static const maximumSequenceTokens = 256;
  static const embeddingSchemaVersion = 2;
  static const minimumAndroidApi = 30;
  static const runtimeTuple =
      'flutter_gemma 1.5.2 / flutter_gemma_embeddings 1.0.4 / '
      'flutter_gemma_litertlm 1.3.1 / LiteRT-LM 0.14.0';
  static const promptContract =
      'flutter_gemma_embeddings-1.0.4-retrieval-prompts-v1';
  static const artifactSetRevision =
      'model-$modelSha256.tokenizer-$tokenizerSha256.'
      'runtime-litertlm-0.14.0.prompt-$promptContract.'
      'schema-$embeddingSchemaVersion';
  static const modelId = '$repository/$modelFileName@$artifactSetRevision';
  static const modelUrl =
      'https://huggingface.co/$repository/resolve/main/$modelFileName';
  static const tokenizerUrl =
      'https://huggingface.co/$repository/resolve/main/$tokenizerFileName';

  // The package API does not expose tokenizer counts and truncates inputs at
  // the tensor sequence length. This conservative guard fails indexing visibly
  // rather than silently dropping reviewed invoice fields.
  static const maximumDocumentCharacters = 512;
  static const maximumQueryCharacters = 256;
  static const requiresAcceptedLicenseAndToken = true;

  static final modelManifest = ModelArtifactManifest(
    modelId: modelId,
    displayName: 'EmbeddingGemma 300M seq256 mixed precision',
    runtime: runtimeTuple,
    fileName: modelFileName,
    revision: modelSha256,
    byteLength: modelByteLength,
    sha256: modelSha256,
    minimumAppVersion: '0.1.0',
    capabilities: const ['retrievalDocument', 'retrievalQuery'],
    format: ModelArtifactFormat.tflite,
    sourceUri: Uri.parse(modelUrl),
    license: 'Gemma Terms of Use; access acceptance required',
    installable: true,
  );

  static final tokenizerManifest = ModelArtifactManifest(
    modelId: '$modelId/tokenizer',
    displayName: 'EmbeddingGemma SentencePiece tokenizer',
    runtime: runtimeTuple,
    fileName: tokenizerFileName,
    revision: tokenizerSha256,
    byteLength: tokenizerByteLength,
    sha256: tokenizerSha256,
    minimumAppVersion: '0.1.0',
    capabilities: const ['tokenization'],
    format: ModelArtifactFormat.sentencePiece,
    sourceUri: Uri.parse(tokenizerUrl),
    license: 'Gemma Terms of Use; access acceptance required',
    installable: true,
  );
}
