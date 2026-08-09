import 'package:flutter/services.dart';

import 'model_manifest.dart';

const String phase7ModelManifestAsset =
    'assets/models/phase7_model_manifest.json';

Future<Phase7ModelManifest> loadPhase7ModelManifest({
  AssetBundle? bundle,
}) async {
  final source = await (bundle ?? rootBundle).loadString(
    phase7ModelManifestAsset,
  );
  return Phase7ModelManifest.parse(source);
}
