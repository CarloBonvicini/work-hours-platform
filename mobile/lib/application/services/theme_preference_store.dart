import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppFontFamily { system, serif, monospace }

class AppAppearanceSettings {
  const AppAppearanceSettings({
    required this.themeMode,
    required this.primaryColor,
    required this.secondaryColor,
    required this.fontFamily,
    required this.textScale,
  });

  final ThemeMode themeMode;
  final Color primaryColor;
  final Color secondaryColor;
  final AppFontFamily fontFamily;
  final double textScale;

  static const defaults = AppAppearanceSettings(
    themeMode: ThemeMode.light,
    primaryColor: Color(0xFF0B6E69),
    secondaryColor: Color(0xFFBF7A24),
    fontFamily: AppFontFamily.system,
    textScale: 1,
  );

  AppAppearanceSettings copyWith({
    ThemeMode? themeMode,
    Color? primaryColor,
    Color? secondaryColor,
    AppFontFamily? fontFamily,
    double? textScale,
  }) {
    return AppAppearanceSettings(
      themeMode: themeMode ?? this.themeMode,
      primaryColor: primaryColor ?? this.primaryColor,
      secondaryColor: secondaryColor ?? this.secondaryColor,
      fontFamily: fontFamily ?? this.fontFamily,
      textScale: textScale ?? this.textScale,
    );
  }
}

abstract class ThemePreferenceStore {
  Future<AppAppearanceSettings> loadAppearanceSettings();

  Future<void> saveAppearanceSettings(AppAppearanceSettings settings);

  Future<ThemeMode> loadThemeMode() async {
    return (await loadAppearanceSettings()).themeMode;
  }

  Future<void> saveThemeMode(ThemeMode themeMode) async {
    final currentSettings = await loadAppearanceSettings();
    await saveAppearanceSettings(currentSettings.copyWith(themeMode: themeMode));
  }
}

class SharedPreferencesThemePreferenceStore implements ThemePreferenceStore {
  const SharedPreferencesThemePreferenceStore();

  static const _themeModeKey = 'appearance.theme_mode';
  static const _primaryColorKey = 'appearance.primary_color';
  static const _secondaryColorKey = 'appearance.secondary_color';
  static const _fontFamilyKey = 'appearance.font_family';
  static const _textScaleKey = 'appearance.text_scale';

  @override
  Future<ThemeMode> loadThemeMode() async {
    return (await loadAppearanceSettings()).themeMode;
  }

  @override
  Future<void> saveThemeMode(ThemeMode themeMode) async {
    final currentSettings = await loadAppearanceSettings();
    await saveAppearanceSettings(currentSettings.copyWith(themeMode: themeMode));
  }

  @override
  Future<AppAppearanceSettings> loadAppearanceSettings() async {
    final preferences = await SharedPreferences.getInstance();
    final rawThemeMode = preferences.getString(_themeModeKey);
    final themeMode = switch (rawThemeMode) {
      'dark' => ThemeMode.dark,
      _ => ThemeMode.light,
    };
    final primaryColor =
        preferences.getInt(_primaryColorKey) ??
        AppAppearanceSettings.defaults.primaryColor.toARGB32();
    final secondaryColor =
        preferences.getInt(_secondaryColorKey) ??
        AppAppearanceSettings.defaults.secondaryColor.toARGB32();
    final fontFamily = switch (preferences.getString(_fontFamilyKey)) {
      'serif' => AppFontFamily.serif,
      'monospace' => AppFontFamily.monospace,
      _ => AppFontFamily.system,
    };
    final textScale = (preferences.getDouble(_textScaleKey) ?? 1).clamp(
      0.9,
      1.25,
    );

    return AppAppearanceSettings(
      themeMode: themeMode,
      primaryColor: Color(primaryColor),
      secondaryColor: Color(secondaryColor),
      fontFamily: fontFamily,
      textScale: textScale,
    );
  }

  @override
  Future<void> saveAppearanceSettings(AppAppearanceSettings settings) async {
    final preferences = await SharedPreferences.getInstance();
    final rawThemeMode = switch (settings.themeMode) {
      ThemeMode.dark => 'dark',
      _ => 'light',
    };
    await preferences.setString(_themeModeKey, rawThemeMode);
    await preferences.setInt(_primaryColorKey, settings.primaryColor.toARGB32());
    await preferences.setInt(
      _secondaryColorKey,
      settings.secondaryColor.toARGB32(),
    );
    await preferences.setString(_fontFamilyKey, settings.fontFamily.name);
    await preferences.setDouble(_textScaleKey, settings.textScale);
  }
}
