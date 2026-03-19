import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract class ThemePreferenceStore {
  Future<ThemeMode> loadThemeMode();

  Future<void> saveThemeMode(ThemeMode themeMode);
}

class SharedPreferencesThemePreferenceStore implements ThemePreferenceStore {
  const SharedPreferencesThemePreferenceStore();

  static const _themeModeKey = 'appearance.theme_mode';

  @override
  Future<ThemeMode> loadThemeMode() async {
    final preferences = await SharedPreferences.getInstance();
    final rawThemeMode = preferences.getString(_themeModeKey);
    return switch (rawThemeMode) {
      'dark' => ThemeMode.dark,
      _ => ThemeMode.light,
    };
  }

  @override
  Future<void> saveThemeMode(ThemeMode themeMode) async {
    final preferences = await SharedPreferences.getInstance();
    final rawThemeMode = switch (themeMode) {
      ThemeMode.dark => 'dark',
      _ => 'light',
    };
    await preferences.setString(_themeModeKey, rawThemeMode);
  }
}
