import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

enum InferenceBackendPreference { automatic, cpu, gpu }

class AppSettings extends Equatable {
  const AppSettings({
    this.localeCode = 'ar',
    this.themeMode = ThemeMode.light,
    this.preferredInferenceBackend = InferenceBackendPreference.automatic,
    this.modelInstallAcknowledged = false,
    this.lastSelectedCaptureSource,
  });

  final String localeCode;
  final ThemeMode themeMode;
  final InferenceBackendPreference preferredInferenceBackend;
  final bool modelInstallAcknowledged;
  final String? lastSelectedCaptureSource;

  AppSettings copyWith({
    String? localeCode,
    ThemeMode? themeMode,
    InferenceBackendPreference? preferredInferenceBackend,
    bool? modelInstallAcknowledged,
    String? lastSelectedCaptureSource,
  }) {
    return AppSettings(
      localeCode: localeCode ?? this.localeCode,
      themeMode: themeMode ?? this.themeMode,
      preferredInferenceBackend:
          preferredInferenceBackend ?? this.preferredInferenceBackend,
      modelInstallAcknowledged:
          modelInstallAcknowledged ?? this.modelInstallAcknowledged,
      lastSelectedCaptureSource:
          lastSelectedCaptureSource ?? this.lastSelectedCaptureSource,
    );
  }

  @override
  List<Object?> get props => [
    localeCode,
    themeMode,
    preferredInferenceBackend,
    modelInstallAcknowledged,
    lastSelectedCaptureSource,
  ];
}
