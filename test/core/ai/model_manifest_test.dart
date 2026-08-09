import 'package:flutter_test/flutter_test.dart';
import 'package:wara2a/core/ai/model_management/model_manifest.dart';

import 'fixture_loader.dart';

void main() {
  test('the pinned Phase 7 manifest is internally valid', () async {
    final manifest = Phase7ModelManifest.parse(
      await loadFixture('../../assets/models/phase7_model_manifest.json'),
    );

    expect(manifest.schemaVersion, 2);
    expect(manifest.artifacts, hasLength(7));
    expect(manifest.byId('ppocrv5-mobile-det-onnx').installable, isTrue);
    final qwen = manifest.byId('qwen2.5-0.5b-instruct-q8-task');
    expect(qwen.format, ModelArtifactFormat.mediaPipeTask);
    expect(qwen.installable, isTrue);
    expect(qwen.byteLength, 546660344);
    expect(
      qwen.sha256,
      'e608953f169aeb1bd7b9155fec2559825e08453fc209b84eda3a781ed0452fd2',
    );
  });

  test('rejects manifest path traversal before building install paths', () {
    expect(
      () => ModelArtifactManifest.fromJson(<String, Object?>{
        'modelId': '../qwen',
        'displayName': 'unsafe',
        'runtime': 'test',
        'fileName': 'model.task',
        'revision': 'revision',
        'byteLength': 1,
        'sha256': '0' * 64,
        'minimumAppVersion': '1.0.0',
        'capabilities': <Object?>['invoice-json'],
        'format': 'mediaPipeTask',
        'sourceUri': 'https://example.test/model.task',
        'license': 'Apache-2.0',
        'installable': true,
      }),
      throwsFormatException,
    );
  });
}
