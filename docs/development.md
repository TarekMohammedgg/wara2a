# Development baseline

Verified on 2026-08-09:

- Flutter 3.44.4 / Dart 3.12.2
- Android application ID: `com.tarek.wara2a`
- Android minimum: API 29 (Android 10); compile/target SDK follow the pinned Flutter toolchain
- iOS deployment target: 16.0; native AI support remains unproven

## Definition-of-done checks

Run from the repository root:

```powershell
flutter pub get
dart run build_runner build --delete-conflicting-outputs
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

Android device and release-build checks remain separate acceptance gates where the implementation plan requires physical hardware.

ObjectBox persistence tests require the native database library. Follow the ObjectBox 5.3.2 README and run its official `install.sh` from Git Bash before `flutter test`; downloaded DLL/shared-library artifacts are intentionally ignored by Git.
