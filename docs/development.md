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

The Android release workflow runs when a tag matching `v*` is pushed, or when started manually from the Actions tab. It builds both an APK and an Android App Bundle. A version tag such as `v1.0.1` also creates a GitHub Release with those files attached.

For Play Store-ready signed artifacts, add these repository secrets:

- `ANDROID_KEYSTORE_BASE64`
- `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEY_PASSWORD`
- `ANDROID_KEY_ALIAS`

Without those secrets the workflow still produces release-mode artifacts, but they are unsigned and are not ready for store distribution. The keystore and generated `android/key.properties` file are never committed.

iOS and macOS releases need a macOS runner plus Apple signing credentials, so they are not included in this Android workflow.
