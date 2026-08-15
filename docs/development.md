# Development baseline

Verified for the cloud OpenRouter stack:

- Flutter stable / Dart from the pinned toolchain
- Android application ID: `com.tarek.wara2a`
- Extraction: OpenRouter Gemini (`google/gemini-2.5-flash-lite`)
- Embeddings: OpenRouter `openai/text-embedding-3-small` (1536-d)
- Invoice images and ObjectBox data stay in the app sandbox

## Definition-of-done checks

Run from the repository root:

```powershell
flutter pub get
dart run build_runner build --delete-conflicting-outputs
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

ObjectBox persistence tests require the native database library. Follow the ObjectBox README and install its native libs before `flutter test` when needed.

## CI/CD and Android releases

GitHub Actions runs on every push and pull request. The CI workflow installs the pinned Flutter toolchain, refreshes Flutter's generated build configuration, checks formatting, runs the analyzer and unit/repository tests, builds a debug APK, and stores that APK as a short-lived workflow artifact.

The two current end-to-end widget flows (`test/widget_test.dart` and `test/features/search/search_view_test.dart`) are not included in the automated test command because they do not settle reliably in the current checkout; they should be repaired before treating CI as a full UI regression gate.

Every commit on the repository default branch also starts the Android release workflow. That job stamps a new version from `pubspec.yaml` plus the workflow run number (`1.0.0+N`), builds a release APK and Android App Bundle, and publishes them as a GitHub Release such as `v1.0.0-N`. Pushing a `v*` tag or running the workflow from the Actions tab does the same.

For Play Store-ready signed artifacts, add these repository secrets:

- `ANDROID_KEYSTORE_BASE64`
- `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEY_PASSWORD`
- `ANDROID_KEY_ALIAS`

Without those secrets the workflow signs with a one-off CI debug key so the APK can be sideloaded. That signature changes between runs, so installing a newer GitHub build may require uninstalling the previous one. The keystore and generated `android/key.properties` file are never committed.

iOS and macOS releases need a macOS runner plus Apple signing credentials, so they are not included in this Android workflow.
