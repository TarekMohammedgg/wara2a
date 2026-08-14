import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_settings.dart';

abstract interface class SettingsRepository {
  Future<AppSettings> load();
  Future<void> save(AppSettings settings);
}

abstract interface class ApiKeyStorage {
  Future<String?> read();
  Future<void> write(String value);
  Future<void> delete();
}

class FlutterApiKeyStorage implements ApiKeyStorage {
  FlutterApiKeyStorage({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const key = 'openrouter.api_key';
  final FlutterSecureStorage _storage;

  @override
  Future<String?> read() => _storage.read(key: key);

  @override
  Future<void> write(String value) => _storage.write(key: key, value: value);

  @override
  Future<void> delete() => _storage.delete(key: key);
}

class SharedPreferencesSettingsRepository implements SettingsRepository {
  SharedPreferencesSettingsRepository({
    SharedPreferencesAsync? preferences,
    ApiKeyStorage? apiKeyStorage,
  }) : _preferences = preferences ?? SharedPreferencesAsync(),
       _apiKeyStorage = apiKeyStorage ?? FlutterApiKeyStorage();

  static const localeKey = 'settings.locale';
  static const themeModeKey = 'settings.theme_mode';
  static const captureSourceKey = 'settings.last_capture_source';
  static const openRouterApiKeyKey = 'settings.openrouter_api_key';
  static const cloudProcessingConsentKey = 'settings.cloud_processing_consent';

  final SharedPreferencesAsync _preferences;
  final ApiKeyStorage _apiKeyStorage;

  @override
  Future<AppSettings> load() async {
    final values = await Future.wait<Object?>([
      _preferences.getString(localeKey),
      _preferences.getString(themeModeKey),
      _preferences.getString(captureSourceKey),
      _preferences.getBool(cloudProcessingConsentKey),
    ]);
    final apiKey = await _loadApiKey();
    return AppSettings(
      localeCode: values[0] == 'en' ? 'en' : 'ar',
      themeMode: _themeMode(values[1] as String?),
      lastSelectedCaptureSource: values[2] as String?,
      openRouterApiKey: apiKey,
      cloudProcessingConsent: values[3] as bool? ?? false,
    );
  }

  @override
  Future<void> save(AppSettings settings) async {
    await Future.wait([
      _preferences.setString(localeKey, settings.localeCode),
      _preferences.setString(themeModeKey, settings.themeMode.name),
      if (settings.lastSelectedCaptureSource == null)
        _preferences.remove(captureSourceKey)
      else
        _preferences.setString(
          captureSourceKey,
          settings.lastSelectedCaptureSource!,
        ),
      _preferences.setBool(
        cloudProcessingConsentKey,
        settings.cloudProcessingConsent,
      ),
    ]);
    final apiKey = settings.openRouterApiKey?.trim();
    if (apiKey == null || apiKey.isEmpty) {
      await _apiKeyStorage.delete();
    } else {
      await _apiKeyStorage.write(apiKey);
    }
    // Remove the legacy plaintext copy only after secure storage succeeds.
    await _preferences.remove(openRouterApiKeyKey);
  }

  Future<String?> _loadApiKey() async {
    final secureValue = (await _apiKeyStorage.read())?.trim();
    if (secureValue != null && secureValue.isNotEmpty) return secureValue;

    final legacyValue = (await _preferences.getString(
      openRouterApiKeyKey,
    ))?.trim();
    if (legacyValue == null || legacyValue.isEmpty) return null;

    // One-time migration for existing users; plaintext storage is removed only
    // after the encrypted write completes.
    await _apiKeyStorage.write(legacyValue);
    await _preferences.remove(openRouterApiKeyKey);
    return legacyValue;
  }

  ThemeMode _themeMode(String? value) => ThemeMode.values.firstWhere(
    (mode) => mode.name == value,
    orElse: () => ThemeMode.light,
  );
}
