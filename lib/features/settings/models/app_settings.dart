import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

class AppSettings extends Equatable {
  const AppSettings({
    this.localeCode = 'ar',
    this.themeMode = ThemeMode.light,
    this.lastSelectedCaptureSource,
    this.openRouterApiKey,
    this.cloudProcessingConsent = false,
  });

  final String localeCode;
  final ThemeMode themeMode;
  final String? lastSelectedCaptureSource;

  /// User-provided OpenRouter API key for cloud extraction and indexing.
  final String? openRouterApiKey;
  final bool cloudProcessingConsent;

  AppSettings copyWith({
    String? localeCode,
    ThemeMode? themeMode,
    String? lastSelectedCaptureSource,
    String? openRouterApiKey,
    bool clearOpenRouterApiKey = false,
    bool? cloudProcessingConsent,
  }) {
    return AppSettings(
      localeCode: localeCode ?? this.localeCode,
      themeMode: themeMode ?? this.themeMode,
      lastSelectedCaptureSource:
          lastSelectedCaptureSource ?? this.lastSelectedCaptureSource,
      openRouterApiKey: clearOpenRouterApiKey
          ? null
          : (openRouterApiKey ?? this.openRouterApiKey),
      cloudProcessingConsent:
          cloudProcessingConsent ?? this.cloudProcessingConsent,
    );
  }

  @override
  List<Object?> get props => [
    localeCode,
    themeMode,
    lastSelectedCaptureSource,
    openRouterApiKey,
    cloudProcessingConsent,
  ];
}
