import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppThemePreference {
  system,
  light,
  dark;

  ThemeMode get themeMode {
    return switch (this) {
      AppThemePreference.system => ThemeMode.system,
      AppThemePreference.light => ThemeMode.light,
      AppThemePreference.dark => ThemeMode.dark,
    };
  }

  String get label {
    return switch (this) {
      AppThemePreference.system => 'System',
      AppThemePreference.light => 'Light',
      AppThemePreference.dark => 'Dark',
    };
  }
}

class AppPreferencesStore extends ChangeNotifier {
  AppPreferencesStore._();

  static final AppPreferencesStore instance = AppPreferencesStore._();
  static const String _themeKey = 'app_theme_preference';
  static const String _avatarColorKey = 'profile_avatar_color';
  static const String _courseNotificationsEnabledKey =
      'course_notifications_enabled';
  static const String _examNotificationsEnabledKey =
      'exam_notifications_enabled';
  static const String _courseReminderMinutesKey = 'course_reminder_minutes';
  static const String _examReminderMinutesKey = 'exam_reminder_minutes';
  static const int defaultAvatarColor = 0xFF35B86F;
  static const int defaultCourseReminderMinutes = 60;
  static const int defaultExamReminderMinutes = 1440;

  AppThemePreference _themePreference = AppThemePreference.system;
  int _avatarColorValue = defaultAvatarColor;
  bool _courseNotificationsEnabled = false;
  bool _examNotificationsEnabled = false;
  int _courseReminderMinutes = defaultCourseReminderMinutes;
  int _examReminderMinutes = defaultExamReminderMinutes;
  bool _isLoaded = false;

  AppThemePreference get themePreference => _themePreference;
  ThemeMode get themeMode => _themePreference.themeMode;
  Color get avatarColor => Color(_avatarColorValue);
  bool get courseNotificationsEnabled => _courseNotificationsEnabled;
  bool get examNotificationsEnabled => _examNotificationsEnabled;
  int get courseReminderMinutes => _courseReminderMinutes;
  int get examReminderMinutes => _examReminderMinutes;
  bool get isLoaded => _isLoaded;

  Future<void> load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? themeName = prefs.getString(_themeKey);
    _themePreference = AppThemePreference.values.firstWhere(
      (AppThemePreference preference) => preference.name == themeName,
      orElse: () => AppThemePreference.system,
    );
    _avatarColorValue = prefs.getInt(_avatarColorKey) ?? defaultAvatarColor;
    _courseNotificationsEnabled =
        prefs.getBool(_courseNotificationsEnabledKey) ?? false;
    _examNotificationsEnabled =
        prefs.getBool(_examNotificationsEnabledKey) ?? false;
    _courseReminderMinutes =
        prefs.getInt(_courseReminderMinutesKey) ?? defaultCourseReminderMinutes;
    _examReminderMinutes =
        prefs.getInt(_examReminderMinutesKey) ?? defaultExamReminderMinutes;
    _isLoaded = true;
    notifyListeners();
  }

  Future<void> setThemePreference(AppThemePreference preference) async {
    if (_themePreference == preference) {
      return;
    }
    _themePreference = preference;
    notifyListeners();
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, preference.name);
  }

  Future<void> setAvatarColor(Color color) async {
    final int value = color.toARGB32();
    if (_avatarColorValue == value) {
      return;
    }
    _avatarColorValue = value;
    notifyListeners();
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_avatarColorKey, value);
  }

  Future<void> setCourseNotificationsEnabled(bool value) async {
    if (_courseNotificationsEnabled == value) {
      return;
    }
    _courseNotificationsEnabled = value;
    notifyListeners();
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_courseNotificationsEnabledKey, value);
  }

  Future<void> setExamNotificationsEnabled(bool value) async {
    if (_examNotificationsEnabled == value) {
      return;
    }
    _examNotificationsEnabled = value;
    notifyListeners();
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_examNotificationsEnabledKey, value);
  }

  Future<void> setCourseReminderMinutes(int value) async {
    final int normalizedValue = _normalizeReminderMinutes(value);
    if (_courseReminderMinutes == normalizedValue) {
      return;
    }
    _courseReminderMinutes = normalizedValue;
    notifyListeners();
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_courseReminderMinutesKey, normalizedValue);
  }

  Future<void> setExamReminderMinutes(int value) async {
    final int normalizedValue = _normalizeReminderMinutes(value);
    if (_examReminderMinutes == normalizedValue) {
      return;
    }
    _examReminderMinutes = normalizedValue;
    notifyListeners();
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_examReminderMinutesKey, normalizedValue);
  }

  int _normalizeReminderMinutes(int value) {
    if (value < 0) {
      return 0;
    }
    if (value > 10080) {
      return 10080;
    }
    return value;
  }
}
