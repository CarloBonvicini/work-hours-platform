import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppFontFamily { system, sansSerif, serif, monospace, rounded, condensed }

enum DayCalendarLayoutMode { quickEditorFirst, agendaFirst }

class AppAppearanceSettings {
  const AppAppearanceSettings({
    required this.themeMode,
    required this.primaryColor,
    required this.secondaryColor,
    this.textColor,
    required this.fontFamily,
    required this.textScale,
    required this.dayCalendarLayoutMode,
    required this.showDayWorkdayCard,
    required this.expandDayWorkdayCard,
    required this.showDayTargetMinutes,
    required this.showDayEndTime,
    required this.showDayBreakMinutes,
  });

  final ThemeMode themeMode;
  final Color primaryColor;
  final Color secondaryColor;
  final Color? textColor;
  final AppFontFamily fontFamily;
  final double textScale;
  final DayCalendarLayoutMode dayCalendarLayoutMode;
  final bool showDayWorkdayCard;
  final bool expandDayWorkdayCard;
  final bool showDayTargetMinutes;
  final bool showDayEndTime;
  final bool showDayBreakMinutes;

  static const defaults = AppAppearanceSettings(
    themeMode: ThemeMode.light,
    primaryColor: Color(0xFF0B6E69),
    secondaryColor: Color(0xFFBF7A24),
    fontFamily: AppFontFamily.system,
    textScale: 1,
    dayCalendarLayoutMode: DayCalendarLayoutMode.quickEditorFirst,
    showDayWorkdayCard: true,
    expandDayWorkdayCard: true,
    showDayTargetMinutes: false,
    showDayEndTime: true,
    showDayBreakMinutes: true,
  );

  AppAppearanceSettings copyWith({
    ThemeMode? themeMode,
    Color? primaryColor,
    Color? secondaryColor,
    Color? textColor,
    bool clearTextColor = false,
    AppFontFamily? fontFamily,
    double? textScale,
    DayCalendarLayoutMode? dayCalendarLayoutMode,
    bool? showDayWorkdayCard,
    bool? expandDayWorkdayCard,
    bool? showDayTargetMinutes,
    bool? showDayEndTime,
    bool? showDayBreakMinutes,
  }) {
    return AppAppearanceSettings(
      themeMode: themeMode ?? this.themeMode,
      primaryColor: primaryColor ?? this.primaryColor,
      secondaryColor: secondaryColor ?? this.secondaryColor,
      textColor: clearTextColor ? null : (textColor ?? this.textColor),
      fontFamily: fontFamily ?? this.fontFamily,
      textScale: textScale ?? this.textScale,
      dayCalendarLayoutMode:
          dayCalendarLayoutMode ?? this.dayCalendarLayoutMode,
      showDayWorkdayCard: showDayWorkdayCard ?? this.showDayWorkdayCard,
      expandDayWorkdayCard: expandDayWorkdayCard ?? this.expandDayWorkdayCard,
      showDayTargetMinutes: showDayTargetMinutes ?? this.showDayTargetMinutes,
      showDayEndTime: showDayEndTime ?? this.showDayEndTime,
      showDayBreakMinutes: showDayBreakMinutes ?? this.showDayBreakMinutes,
    );
  }

  factory AppAppearanceSettings.fromJson(Map<String, dynamic> json) {
    final rawThemeMode = json['themeMode'] as String?;
    return AppAppearanceSettings(
      themeMode: switch (rawThemeMode) {
        'dark' => ThemeMode.dark,
        'system' => ThemeMode.system,
        _ => ThemeMode.light,
      },
      primaryColor: Color(
        (json['primaryColor'] as int?) ??
            AppAppearanceSettings.defaults.primaryColor.toARGB32(),
      ),
      secondaryColor: Color(
        (json['secondaryColor'] as int?) ??
            AppAppearanceSettings.defaults.secondaryColor.toARGB32(),
      ),
      textColor: json['textColor'] is int
          ? Color(json['textColor'] as int)
          : null,
      fontFamily: switch (json['fontFamily'] as String?) {
        'sansSerif' => AppFontFamily.sansSerif,
        'serif' => AppFontFamily.serif,
        'monospace' => AppFontFamily.monospace,
        'rounded' => AppFontFamily.rounded,
        'condensed' => AppFontFamily.condensed,
        _ => AppFontFamily.system,
      },
      textScale: ((json['textScale'] as num?)?.toDouble() ?? 1).clamp(0.8, 1.5),
      dayCalendarLayoutMode: switch (json['dayCalendarLayoutMode'] as String?) {
        'agendaFirst' => DayCalendarLayoutMode.agendaFirst,
        _ => DayCalendarLayoutMode.quickEditorFirst,
      },
      showDayWorkdayCard:
          json['showDayWorkdayCard'] as bool? ??
          AppAppearanceSettings.defaults.showDayWorkdayCard,
      expandDayWorkdayCard:
          json['expandDayWorkdayCard'] as bool? ??
          AppAppearanceSettings.defaults.expandDayWorkdayCard,
      showDayTargetMinutes:
          json['showDayTargetMinutes'] as bool? ??
          AppAppearanceSettings.defaults.showDayTargetMinutes,
      showDayEndTime:
          json['showDayEndTime'] as bool? ??
          AppAppearanceSettings.defaults.showDayEndTime,
      showDayBreakMinutes:
          json['showDayBreakMinutes'] as bool? ??
          AppAppearanceSettings.defaults.showDayBreakMinutes,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'themeMode': switch (themeMode) {
        ThemeMode.dark => 'dark',
        ThemeMode.system => 'system',
        _ => 'light',
      },
      'primaryColor': primaryColor.toARGB32(),
      'secondaryColor': secondaryColor.toARGB32(),
      if (textColor != null) 'textColor': textColor!.toARGB32(),
      'fontFamily': fontFamily.name,
      'textScale': textScale,
      'dayCalendarLayoutMode': dayCalendarLayoutMode.name,
      'showDayWorkdayCard': showDayWorkdayCard,
      'expandDayWorkdayCard': expandDayWorkdayCard,
      'showDayTargetMinutes': showDayTargetMinutes,
      'showDayEndTime': showDayEndTime,
      'showDayBreakMinutes': showDayBreakMinutes,
    };
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
    await saveAppearanceSettings(
      currentSettings.copyWith(themeMode: themeMode),
    );
  }
}

class SharedPreferencesThemePreferenceStore implements ThemePreferenceStore {
  const SharedPreferencesThemePreferenceStore();

  static const _themeModeKey = 'appearance.theme_mode';
  static const _primaryColorKey = 'appearance.primary_color';
  static const _secondaryColorKey = 'appearance.secondary_color';
  static const _textColorKey = 'appearance.text_color';
  static const _fontFamilyKey = 'appearance.font_family';
  static const _textScaleKey = 'appearance.text_scale';
  static const _dayCalendarLayoutModeKey =
      'appearance.day_calendar_layout_mode';
  static const _showDayWorkdayCardKey = 'appearance.show_day_workday_card';
  static const _expandDayWorkdayCardKey = 'appearance.expand_day_workday_card';
  static const _showDayTargetMinutesKey = 'appearance.show_day_target_minutes';
  static const _showDayEndTimeKey = 'appearance.show_day_end_time';
  static const _showDayBreakMinutesKey = 'appearance.show_day_break_minutes';

  @override
  Future<ThemeMode> loadThemeMode() async {
    return (await loadAppearanceSettings()).themeMode;
  }

  @override
  Future<void> saveThemeMode(ThemeMode themeMode) async {
    final currentSettings = await loadAppearanceSettings();
    await saveAppearanceSettings(
      currentSettings.copyWith(themeMode: themeMode),
    );
  }

  @override
  Future<AppAppearanceSettings> loadAppearanceSettings() async {
    final preferences = await SharedPreferences.getInstance();
    final rawThemeMode = preferences.getString(_themeModeKey);
    final themeMode = switch (rawThemeMode) {
      'dark' => ThemeMode.dark,
      'system' => ThemeMode.system,
      _ => ThemeMode.light,
    };
    final primaryColor =
        preferences.getInt(_primaryColorKey) ??
        AppAppearanceSettings.defaults.primaryColor.toARGB32();
    final secondaryColor =
        preferences.getInt(_secondaryColorKey) ??
        AppAppearanceSettings.defaults.secondaryColor.toARGB32();
    final textColor = preferences.getInt(_textColorKey);
    final fontFamily = switch (preferences.getString(_fontFamilyKey)) {
      'sansSerif' => AppFontFamily.sansSerif,
      'serif' => AppFontFamily.serif,
      'monospace' => AppFontFamily.monospace,
      'rounded' => AppFontFamily.rounded,
      'condensed' => AppFontFamily.condensed,
      _ => AppFontFamily.system,
    };
    final textScale = (preferences.getDouble(_textScaleKey) ?? 1).clamp(
      0.8,
      1.5,
    );
    final dayCalendarLayoutMode = switch (preferences.getString(
      _dayCalendarLayoutModeKey,
    )) {
      'agendaFirst' => DayCalendarLayoutMode.agendaFirst,
      _ => DayCalendarLayoutMode.quickEditorFirst,
    };

    return AppAppearanceSettings(
      themeMode: themeMode,
      primaryColor: Color(primaryColor),
      secondaryColor: Color(secondaryColor),
      textColor: textColor == null ? null : Color(textColor),
      fontFamily: fontFamily,
      textScale: textScale,
      dayCalendarLayoutMode: dayCalendarLayoutMode,
      showDayWorkdayCard:
          preferences.getBool(_showDayWorkdayCardKey) ??
          AppAppearanceSettings.defaults.showDayWorkdayCard,
      expandDayWorkdayCard:
          preferences.getBool(_expandDayWorkdayCardKey) ??
          AppAppearanceSettings.defaults.expandDayWorkdayCard,
      showDayTargetMinutes:
          preferences.getBool(_showDayTargetMinutesKey) ??
          AppAppearanceSettings.defaults.showDayTargetMinutes,
      showDayEndTime:
          preferences.getBool(_showDayEndTimeKey) ??
          AppAppearanceSettings.defaults.showDayEndTime,
      showDayBreakMinutes:
          preferences.getBool(_showDayBreakMinutesKey) ??
          AppAppearanceSettings.defaults.showDayBreakMinutes,
    );
  }

  @override
  Future<void> saveAppearanceSettings(AppAppearanceSettings settings) async {
    final preferences = await SharedPreferences.getInstance();
    final rawThemeMode = switch (settings.themeMode) {
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
      _ => 'light',
    };
    await preferences.setString(_themeModeKey, rawThemeMode);
    await preferences.setInt(
      _primaryColorKey,
      settings.primaryColor.toARGB32(),
    );
    await preferences.setInt(
      _secondaryColorKey,
      settings.secondaryColor.toARGB32(),
    );
    if (settings.textColor == null) {
      await preferences.remove(_textColorKey);
    } else {
      await preferences.setInt(_textColorKey, settings.textColor!.toARGB32());
    }
    await preferences.setString(_fontFamilyKey, settings.fontFamily.name);
    await preferences.setDouble(_textScaleKey, settings.textScale);
    await preferences.setString(
      _dayCalendarLayoutModeKey,
      settings.dayCalendarLayoutMode.name,
    );
    await preferences.setBool(
      _showDayWorkdayCardKey,
      settings.showDayWorkdayCard,
    );
    await preferences.setBool(
      _expandDayWorkdayCardKey,
      settings.expandDayWorkdayCard,
    );
    await preferences.setBool(
      _showDayTargetMinutesKey,
      settings.showDayTargetMinutes,
    );
    await preferences.setBool(_showDayEndTimeKey, settings.showDayEndTime);
    await preferences.setBool(
      _showDayBreakMinutesKey,
      settings.showDayBreakMinutes,
    );
  }
}
