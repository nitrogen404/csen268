class AppSettings {
  final bool notificationsEnabled;
  final bool remindersEnabled;
  final String? reminderTime;
  /// "light" | "dark" | "system"
  final String darkMode;
  /// e.g. "en", "es"
  final String language;

  const AppSettings({
    this.notificationsEnabled = true,
    this.remindersEnabled = false,
    this.reminderTime,
    this.darkMode = 'system',
    this.language = 'en',
  });

  AppSettings copyWith({
    bool? notificationsEnabled,
    bool? remindersEnabled,
    String? reminderTime,
    String? darkMode,
    String? language,
  }) {
    return AppSettings(
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      remindersEnabled: remindersEnabled ?? this.remindersEnabled,
      reminderTime: reminderTime ?? this.reminderTime,
      darkMode: darkMode ?? this.darkMode,
      language: language ?? this.language,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'notifications_enabled': notificationsEnabled,
      'reminders_enabled': remindersEnabled,
      'reminder_time': reminderTime,
      'dark_mode': darkMode,
      'language': language,
    };
  }

  factory AppSettings.fromMap(Map<String, dynamic>? map) {
    if (map == null) {
      return const AppSettings();
    }
    return AppSettings(
      notificationsEnabled:
          (map['notifications_enabled'] as bool?) ?? true,
      remindersEnabled:
          (map['reminders_enabled'] as bool?) ?? false,
      reminderTime: map['reminder_time'] as String?,
      darkMode: (map['dark_mode'] as String?) ?? 'system',
      language: (map['language'] as String?) ?? 'en',
    );
  }
}


