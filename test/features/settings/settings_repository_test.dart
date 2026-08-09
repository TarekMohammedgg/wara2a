import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:wara2a/features/settings/models/app_settings.dart';
import 'package:wara2a/features/settings/repositories/settings_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  tearDown(() => SharedPreferencesAsyncPlatform.instance = null);

  test('round-trips only typed non-critical settings', () async {
    final repository = SharedPreferencesSettingsRepository(
      preferences: SharedPreferencesAsync(),
    );
    const expected = AppSettings(
      localeCode: 'en',
      themeMode: ThemeMode.dark,
      preferredInferenceBackend: InferenceBackendPreference.cpu,
      modelInstallAcknowledged: true,
      lastSelectedCaptureSource: 'gallery',
    );

    await repository.save(expected);

    expect(await repository.load(), expected);
    final preferences = SharedPreferencesAsync();
    expect(
      await preferences.getKeys(),
      containsAll(<String>{
        SharedPreferencesSettingsRepository.localeKey,
        SharedPreferencesSettingsRepository.themeModeKey,
        SharedPreferencesSettingsRepository.inferenceBackendKey,
        SharedPreferencesSettingsRepository.modelAcknowledgedKey,
        SharedPreferencesSettingsRepository.captureSourceKey,
      }),
    );
    expect(
      (await preferences.getKeys()).where(
        (key) => key.contains('invoice') || key.contains('embedding'),
      ),
      isEmpty,
    );
  });
}
