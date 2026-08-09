import 'package:flutter_test/flutter_test.dart';
import 'package:wara2a/core/ai/model_management/model_manifest.dart';

import 'fixture_loader.dart';

void main() {
  test('the pinned Phase 7 manifest is internally valid', () async {
    final manifest = Phase7ModelManifest.parse(
      await loadFixture('../../assets/models/phase7_model_manifest.json'),
    );

    expect(manifest.schemaVersion, 1);
    expect(manifest.artifacts, hasLength(7));
    expect(manifest.byId('ppocrv5-mobile-det-onnx').installable, isTrue);
    final qwen = manifest.byId('qwen2.5-0.5b-q8-current-container');
    expect(qwen.format, ModelArtifactFormat.mediaPipeTask);
    expect(qwen.installable, isFalse);
  });
}
