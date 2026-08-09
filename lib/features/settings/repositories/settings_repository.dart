import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_settings.dart';

abstract interface class SettingsRepository {
  Future<AppSettings> load();
  Future<void> save(AppSettings settings);
}

class SharedPreferencesSettingsRepository implements SettingsRepository {
  SharedPreferencesSettingsRepository({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  static const localeKey = 'settings.locale';
  static const themeModeKey = 'settings.theme_mode';
  static const inferenceBackendKey = 'settings.inference_backend';
  static const modelAcknowledgedKey = 'settings.model_install_acknowledged';
  static const captureSourceKey = 'settings.last_capture_source';

  final SharedPreferencesAsync _preferences;

  @override
  Future<AppSettings> load() async {
    final values = await Future.wait<Object?>([
      _preferences.getString(localeKey),
      _preferences.getString(themeModeKey),
      _preferences.getString(inferenceBackendKey),
      _preferences.getBool(modelAcknowledgedKey),
      _preferences.getString(captureSourceKey),
    ]);
    return AppSettings(
      localeCode: values[0] == 'en' ? 'en' : 'ar',
      themeMode: _themeMode(values[1] as String?),
      preferredInferenceBackend: _backend(values[2] as String?),
      modelInstallAcknowledged: values[3] as bool? ?? false,
      lastSelectedCaptureSource: values[4] as String?,
    );
  }

  @override
  Future<void> save(AppSettings settings) async {
    await Future.wait([
      _preferences.setString(localeKey, settings.localeCode),
      _preferences.setString(themeModeKey, settings.themeMode.name),
      _preferences.setString(
        inferenceBackendKey,
        settings.preferredInferenceBackend.name,
      ),
      _preferences.setBool(
        modelAcknowledgedKey,
        settings.modelInstallAcknowledged,
      ),
      if (settings.lastSelectedCaptureSource == null)
        _preferences.remove(captureSourceKey)
      else
        _preferences.setString(
          captureSourceKey,
          settings.lastSelectedCaptureSource!,
        ),
    ]);
  }

  ThemeMode _themeMode(String? value) => ThemeMode.values.firstWhere(
    (mode) => mode.name == value,
    orElse: () => ThemeMode.light,
  );

  InferenceBackendPreference _backend(String? value) =>
      InferenceBackendPreference.values.firstWhere(
        (backend) => backend.name == value,
        orElse: () => InferenceBackendPreference.automatic,
      );
}
