import '../model_management/model_manifest.dart';

/// Immutable deployment contract for Wara2a's offline semantic index.
abstract final class MultilingualE5Artifact {
  static const repository = 'intfloat/multilingual-e5-small';
  static const revision = '614241f622f53c4eeff9890bdc4f31cfecc418b3';
  static const modelId = 'intfloat-multilingual-e5-small-qint8-614241f';
  static const displayName = 'multilingual-e5-small (qint8)';
  static const license = 'MIT';
  static const dimensions = 384;
  static const embeddingSchemaVersion = 3;
  static const maximumSequenceTokens = 512;
  static const maximumInputCharacters = 16000;
  static const minimumAndroidApi = 30;
  static const queryPrefix = 'query: ';
  static const documentPrefix = 'passage: ';
  static const retrievalQueryTask = 'task: search result | query: ';
  static const promptContract = 'e5-wara2a-retrieval-prefix-v1';
  static const runtimeTuple =
      'ONNX Runtime Android 1.21.1 + ONNX Runtime Extensions Android 0.13.0';

  static const tokenizerAssetPath =
      'embedding/multilingual_e5_small_tokenizer.onnx';
  static const tokenizerGraphByteLength = 5069598;
  static const tokenizerGraphSha256 =
      '9f063c3b86fb5e336b5560b240e49204671bf59766e61ea68bb5462001b5c06b';
  static const sentencePieceByteLength = 5069051;
  static const sentencePieceSha256 =
      'cfc8146abe2a0488e9e2a0c56de7952f7c11ab059eca145a0a727afce0db2865';
  static const onnxRuntimeAndroidAarByteLength = 27944395;
  static const onnxRuntimeAndroidAarSha256 =
      '30e594a4b9246fe3ca25768570e90f71e6d33ceb7b7dd72f92dcd7c267611d3f';
  static const onnxRuntimeExtensionsAndroidAarByteLength = 9040811;
  static const onnxRuntimeExtensionsAndroidAarSha256 =
      'cb98c6fbeac1a9707228c4b76cfbb395b4dc4d310900aefaa672561d17fd6d9d';

  // The upstream name describes the exporter host. Inspection found only
  // standard ai.onnx ops (opset 11); Android eligibility is nevertheless
  // accepted only after the pinned file executes on the physical arm64 gate.
  static const modelFileName = 'model_qint8_avx512_vnni.onnx';
  static const modelByteLength = 118346824;
  static const modelSha256 =
      'dd476dd0c2514e9b9be83aeb3853fac0763e0bdf4a71645407587d77c48a2d88';
  static final Uri modelUri = Uri.parse(
    'https://huggingface.co/$repository/resolve/$revision/'
    'onnx/$modelFileName?download=true',
  );

  static final ModelArtifactManifest modelManifest = ModelArtifactManifest(
    modelId: modelId,
    displayName: displayName,
    runtime: runtimeTuple,
    fileName: modelFileName,
    revision: revision,
    byteLength: modelByteLength,
    sha256: modelSha256,
    minimumAppVersion: '1.0.0',
    capabilities: const <String>[
      'embedding',
      'arabic',
      'english',
      'mixed-arabic-english',
      'offline',
    ],
    format: ModelArtifactFormat.onnx,
    sourceUri: modelUri,
    license: license,
    installable: true,
  );

  static String formatQuery(String value) =>
      '$queryPrefix$retrievalQueryTask${value.trim()}';

  static String formatDocument(String value, {String? title}) {
    final normalizedTitle = title?.trim();
    return '$documentPrefix'
        'title: ${normalizedTitle?.isNotEmpty == true ? normalizedTitle : 'none'} '
        '| text: ${value.trim()}';
  }
}
