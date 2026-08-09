import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../models/app_settings.dart';
import '../repositories/settings_repository.dart';

enum SettingsStatus { initial, loading, ready, failure }

class SettingsState extends Equatable {
  const SettingsState({
    this.status = SettingsStatus.initial,
    this.settings = const AppSettings(),
    this.errorMessage,
  });

  final SettingsStatus status;
  final AppSettings settings;
  final String? errorMessage;

  @override
  List<Object?> get props => [status, settings, errorMessage];
}

class SettingsCubit extends Cubit<SettingsState> {
  SettingsCubit(this._repository) : super(const SettingsState());

  final SettingsRepository _repository;

  Future<void> load() async {
    emit(
      SettingsState(status: SettingsStatus.loading, settings: state.settings),
    );
    try {
      final settings = await _repository.load();
      emit(SettingsState(status: SettingsStatus.ready, settings: settings));
    } catch (error) {
      emit(
        SettingsState(
          status: SettingsStatus.failure,
          settings: state.settings,
          errorMessage: error.toString(),
        ),
      );
    }
  }

  Future<void> setLocale(Locale locale) =>
      _persist(state.settings.copyWith(localeCode: locale.languageCode));

  Future<void> setThemeMode(ThemeMode themeMode) =>
      _persist(state.settings.copyWith(themeMode: themeMode));

  Future<void> _persist(AppSettings settings) async {
    final previous = state.settings;
    emit(SettingsState(status: SettingsStatus.ready, settings: settings));
    try {
      await _repository.save(settings);
    } catch (error) {
      emit(
        SettingsState(
          status: SettingsStatus.failure,
          settings: previous,
          errorMessage: error.toString(),
        ),
      );
    }
  }
}
