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
    final apiKeyStorage = _FakeApiKeyStorage();
    final repository = SharedPreferencesSettingsRepository(
      preferences: SharedPreferencesAsync(),
      apiKeyStorage: apiKeyStorage,
    );
    const expected = AppSettings(
      localeCode: 'en',
      themeMode: ThemeMode.dark,
      lastSelectedCaptureSource: 'gallery',
      openRouterApiKey: 'sk-or-test',
      cloudProcessingConsent: true,
    );

    await repository.save(expected);

    expect(await repository.load(), expected);
    final preferences = SharedPreferencesAsync();
    expect(
      await preferences.getKeys(),
      containsAll(<String>{
        SharedPreferencesSettingsRepository.localeKey,
        SharedPreferencesSettingsRepository.themeModeKey,
        SharedPreferencesSettingsRepository.captureSourceKey,
        SharedPreferencesSettingsRepository.cloudProcessingConsentKey,
      }),
    );
    expect(
      (await preferences.getKeys()).contains(
        SharedPreferencesSettingsRepository.openRouterApiKeyKey,
      ),
      isFalse,
    );
    expect(apiKeyStorage.value, 'sk-or-test');
    expect(
      (await preferences.getKeys()).where(
        (key) => key.contains('invoice') || key.contains('embedding'),
      ),
      isEmpty,
    );
  });

  test('migrates a legacy plaintext key into secure storage once', () async {
    final preferences = SharedPreferencesAsync();
    await preferences.setString(
      SharedPreferencesSettingsRepository.openRouterApiKeyKey,
      'legacy-key',
    );
    final apiKeyStorage = _FakeApiKeyStorage();
    final repository = SharedPreferencesSettingsRepository(
      preferences: preferences,
      apiKeyStorage: apiKeyStorage,
    );

    expect((await repository.load()).openRouterApiKey, 'legacy-key');
    expect(apiKeyStorage.value, 'legacy-key');
    expect(
      await preferences.getString(
        SharedPreferencesSettingsRepository.openRouterApiKeyKey,
      ),
      isNull,
    );
  });
}

class _FakeApiKeyStorage implements ApiKeyStorage {
  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String value) async => this.value = value;

  @override
  Future<void> delete() async => value = null;
}
