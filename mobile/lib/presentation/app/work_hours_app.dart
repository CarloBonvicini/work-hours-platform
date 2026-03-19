import 'package:flutter/material.dart';
import 'package:work_hours_mobile/application/services/app_update_service.dart';
import 'package:work_hours_mobile/application/services/dashboard_service.dart';
import 'package:work_hours_mobile/application/services/onboarding_preference_store.dart';
import 'package:work_hours_mobile/application/services/theme_preference_store.dart';
import 'package:work_hours_mobile/application/services/update_reminder_store.dart';
import 'package:work_hours_mobile/presentation/home/home_screen.dart';

class WorkHoursApp extends StatefulWidget {
  const WorkHoursApp({
    super.key,
    required this.dashboardService,
    required this.appUpdateService,
    required this.updateReminderStore,
    required this.themePreferenceStore,
    required this.onboardingPreferenceStore,
    this.initialThemeMode = ThemeMode.light,
    this.hasCompletedInitialSetup = false,
  });

  final DashboardService dashboardService;
  final AppUpdateService appUpdateService;
  final UpdateReminderStore updateReminderStore;
  final ThemePreferenceStore themePreferenceStore;
  final OnboardingPreferenceStore onboardingPreferenceStore;
  final ThemeMode initialThemeMode;
  final bool hasCompletedInitialSetup;

  @override
  State<WorkHoursApp> createState() => _WorkHoursAppState();
}

class _WorkHoursAppState extends State<WorkHoursApp> {
  late ThemeMode _themeMode;

  @override
  void initState() {
    super.initState();
    _themeMode = widget.initialThemeMode;
  }

  Future<void> _updateThemeMode(bool useDarkTheme) async {
    final nextThemeMode = useDarkTheme ? ThemeMode.dark : ThemeMode.light;
    if (_themeMode == nextThemeMode) {
      return;
    }

    setState(() {
      _themeMode = nextThemeMode;
    });

    await widget.themePreferenceStore.saveThemeMode(nextThemeMode);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Work Hours Platform',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      themeMode: _themeMode,
      home: HomeScreen(
        dashboardService: widget.dashboardService,
        appUpdateService: widget.appUpdateService,
        updateReminderStore: widget.updateReminderStore,
        onboardingPreferenceStore: widget.onboardingPreferenceStore,
        hasCompletedInitialSetup: widget.hasCompletedInitialSetup,
        isDarkTheme: _themeMode == ThemeMode.dark,
        onThemeModeChanged: _updateThemeMode,
      ),
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    const accentColor = Color(0xFF0B6E69);
    final isDark = brightness == Brightness.dark;
    final canvasColor = isDark
        ? const Color(0xFF0D1414)
        : const Color(0xFFF5F1E8);
    final inkColor = isDark ? const Color(0xFFE8F0EF) : const Color(0xFF1A2A2A);
    final fieldColor = isDark ? const Color(0xFF162121) : Colors.white;
    final borderColor = isDark
        ? const Color(0xFF324343)
        : const Color(0xFFD8CEC0);
    final selectedChipColor = isDark
        ? const Color(0xFF164E4B)
        : const Color(0xFFDCEFE8);

    return ThemeData(
      brightness: brightness,
      colorScheme: ColorScheme.fromSeed(
        seedColor: accentColor,
        brightness: brightness,
        surface: canvasColor,
      ),
      scaffoldBackgroundColor: canvasColor,
      textTheme: ThemeData(
        brightness: brightness,
      ).textTheme.apply(bodyColor: inkColor, displayColor: inkColor),
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
          borderSide: const BorderSide(color: accentColor, width: 1.4),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        selectedColor: selectedChipColor,
        backgroundColor: fieldColor,
        side: BorderSide(color: borderColor),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
      useMaterial3: true,
    );
  }
}
