import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../models/app_settings.dart';
import '../repository/settings_repository.dart';
import '../services/reminder_service.dart';

class SettingsState {
  final AppSettings? settings;
  final bool isLoading;
  final String? error;

  const SettingsState({
    this.settings,
    this.isLoading = false,
    this.error,
  });

  SettingsState copyWith({
    AppSettings? settings,
    bool? isLoading,
    String? error,
  }) {
    return SettingsState(
      settings: settings ?? this.settings,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class SettingsCubit extends Cubit<SettingsState> {
  final SettingsRepository _repository;
  final String _uid;
  final ReminderService? _reminderService;
  StreamSubscription<AppSettings>? _sub;

  SettingsCubit(this._repository, this._uid, [this._reminderService])
      : super(const SettingsState(isLoading: true)) {
    _init();
  }

  Future<void> _init() async {
    emit(state.copyWith(isLoading: true, error: null));
    try {
      final initial = await _repository.getSettings(_uid);
      emit(SettingsState(settings: initial, isLoading: false));

      // Schedule reminders if enabled
      if (initial.remindersEnabled && _reminderService != null) {
        await _reminderService!.scheduleReminders(reschedule: true);
      }

      _sub?.cancel();
      _sub = _repository.watchSettings(_uid).listen((settings) {
        emit(SettingsState(settings: settings, isLoading: false));
      });
    } catch (e) {
      emit(SettingsState(
        settings: state.settings,
        isLoading: false,
        error: e.toString(),
      ));
    }
  }

  Future<void> _update(AppSettings newSettings) async {
    emit(state.copyWith(settings: newSettings, isLoading: false, error: null));
    await _repository.updateSettings(_uid, newSettings);
  }

  Future<void> toggleNotifications(bool enabled) async {
    final current = state.settings ?? const AppSettings();
    await _update(current.copyWith(notificationsEnabled: enabled));
  }

  Future<void> toggleReminders(bool enabled) async {
    final current = state.settings ?? const AppSettings();
    await _update(current.copyWith(remindersEnabled: enabled));
    
    // Schedule or cancel reminders based on toggle
    if (_reminderService != null) {
      await _reminderService!.updateReminders(enabled);
    }
  }

  Future<void> toggleDarkMode(String mode) async {
    final current = state.settings ?? const AppSettings();
    await _update(current.copyWith(darkMode: mode));
  }

  Future<void> setLanguage(String language) async {
    final current = state.settings ?? const AppSettings();
    await _update(current.copyWith(language: language));
  }

  Future<void> setReminderTime(String? time) async {
    final current = state.settings ?? const AppSettings();
    await _update(current.copyWith(reminderTime: time));
  }

  @override
  Future<void> close() {
    _sub?.cancel();
    return super.close();
  }
}


