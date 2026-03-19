import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:work_hours_mobile/application/services/app_update_service.dart';
import 'package:work_hours_mobile/application/services/dashboard_service.dart';
import 'package:work_hours_mobile/application/services/onboarding_preference_store.dart';
import 'package:work_hours_mobile/application/services/theme_preference_store.dart';
import 'package:work_hours_mobile/application/services/update_reminder_store.dart';
import 'package:work_hours_mobile/application/services/workday_start_store.dart';
import 'package:work_hours_mobile/presentation/home/home_screen.dart';

class WorkHoursApp extends StatefulWidget {
  const WorkHoursApp({
    super.key,
    required this.dashboardService,
    required this.appUpdateService,
    required this.updateReminderStore,
    required this.themePreferenceStore,
    required this.onboardingPreferenceStore,
    required this.workdayStartStore,
    this.initialAppearanceSettings = AppAppearanceSettings.defaults,
    this.hasCompletedInitialSetup = false,
  });

  final DashboardService dashboardService;
  final AppUpdateService appUpdateService;
  final UpdateReminderStore updateReminderStore;
  final ThemePreferenceStore themePreferenceStore;
  final OnboardingPreferenceStore onboardingPreferenceStore;
  final WorkdayStartStore workdayStartStore;
  final AppAppearanceSettings initialAppearanceSettings;
  final bool hasCompletedInitialSetup;

  @override
  State<WorkHoursApp> createState() => _WorkHoursAppState();
}

class _WorkHoursAppState extends State<WorkHoursApp> {
  static const _lightCanvasColor = Color(0xFFF5F1E8);
  static const _darkCanvasColor = Color(0xFF0D1414);

  late AppAppearanceSettings _appearanceSettings;

  @override
  void initState() {
    super.initState();
    _appearanceSettings = widget.initialAppearanceSettings;
  }

  Future<void> _updateThemeMode(bool useDarkTheme) async {
    final nextThemeMode = useDarkTheme ? ThemeMode.dark : ThemeMode.light;
    if (_appearanceSettings.themeMode == nextThemeMode) {
      return;
    }

    await _updateAppearanceSettings(
      _appearanceSettings.copyWith(themeMode: nextThemeMode),
    );
  }

  Future<void> _updateAppearanceSettings(
    AppAppearanceSettings nextSettings,
  ) async {
    setState(() {
      _appearanceSettings = nextSettings;
    });

    await widget.themePreferenceStore.saveAppearanceSettings(nextSettings);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Work Hours Platform',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      themeMode: _appearanceSettings.themeMode,
      home: HomeScreen(
        dashboardService: widget.dashboardService,
        appUpdateService: widget.appUpdateService,
        updateReminderStore: widget.updateReminderStore,
        onboardingPreferenceStore: widget.onboardingPreferenceStore,
        workdayStartStore: widget.workdayStartStore,
        hasCompletedInitialSetup: widget.hasCompletedInitialSetup,
        isDarkTheme: _appearanceSettings.themeMode == ThemeMode.dark,
        appearanceSettings: _appearanceSettings,
        onAppearanceSettingsChanged: _updateAppearanceSettings,
        onThemeModeChanged: _updateThemeMode,
      ),
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final primaryColor = _appearanceSettings.primaryColor;
    final secondaryColor = _appearanceSettings.secondaryColor;
    final canvasColor = Color.lerp(
      isDark ? _darkCanvasColor : _lightCanvasColor,
      primaryColor,
      isDark ? 0.16 : 0.08,
    )!;
    final inkColor = isDark ? const Color(0xFFE8F0EF) : const Color(0xFF1A2A2A);
    final fieldColor = Color.lerp(
      isDark ? const Color(0xFF162121) : Colors.white,
      primaryColor,
      isDark ? 0.1 : 0.04,
    )!;
    final borderColor = isDark
        ? const Color(0xFF324343)
        : const Color(0xFFD8CEC0);
    final selectedChipColor = Color.lerp(
      isDark ? const Color(0xFF164E4B) : const Color(0xFFDCEFE8),
      primaryColor,
      0.28,
    )!;
    final baseTextTheme = ThemeData(brightness: brightness).textTheme.apply(
      bodyColor: inkColor,
      displayColor: inkColor,
      fontSizeFactor: _appearanceSettings.textScale,
    );
    final themedTextTheme = switch (_appearanceSettings.fontFamily) {
      AppFontFamily.serif => GoogleFonts.loraTextTheme(baseTextTheme),
      AppFontFamily.monospace => GoogleFonts.ibmPlexMonoTextTheme(
        baseTextTheme,
      ),
      AppFontFamily.system => baseTextTheme,
    };
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: primaryColor,
          brightness: brightness,
          surface: canvasColor,
        ).copyWith(
          primary: primaryColor,
          secondary: secondaryColor,
          tertiary: secondaryColor,
        );

    return ThemeData(
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: canvasColor,
      textTheme: themedTextTheme,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: fieldColor,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: primaryColor, width: 1.4),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: colorScheme.onPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryColor,
          side: BorderSide(color: primaryColor.withValues(alpha: 0.45)),
        ),
      ),
      chipTheme: ChipThemeData(
        selectedColor: selectedChipColor,
        backgroundColor: fieldColor,
        side: BorderSide(color: borderColor),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: primaryColor,
        thumbColor: primaryColor,
        inactiveTrackColor: primaryColor.withValues(alpha: 0.22),
      ),
      useMaterial3: true,
    );
  }
}
