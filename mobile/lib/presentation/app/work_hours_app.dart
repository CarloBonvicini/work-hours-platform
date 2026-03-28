import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:work_hours_mobile/application/services/account_service.dart';
import 'package:work_hours_mobile/application/services/app_update_service.dart';
import 'package:work_hours_mobile/application/services/dashboard_service.dart';
import 'package:work_hours_mobile/application/services/dashboard_snapshot_store.dart';
import 'package:work_hours_mobile/application/services/onboarding_preference_store.dart';
import 'package:work_hours_mobile/application/services/remote_push_registration_service.dart';
import 'package:work_hours_mobile/application/services/support_ticket_store.dart';
import 'package:work_hours_mobile/application/services/theme_preference_store.dart';
import 'package:work_hours_mobile/application/services/update_reminder_store.dart';
import 'package:work_hours_mobile/application/services/workday_start_store.dart';
import 'package:work_hours_mobile/domain/models/account_session.dart';
import 'package:work_hours_mobile/presentation/home/home_screen.dart';

class WorkHoursApp extends StatefulWidget {
  const WorkHoursApp({
    super.key,
    required this.dashboardService,
    required this.appUpdateService,
    required this.updateReminderStore,
    this.dashboardSnapshotStore = const InMemoryDashboardSnapshotStore(),
    required this.themePreferenceStore,
    required this.onboardingPreferenceStore,
    required this.workdayStartStore,
    this.supportTicketStore = const SharedPreferencesSupportTicketStore(),
    this.accountService,
    this.remotePushRegistrationService,
    this.initialAccountSession,
    this.initialAppearanceSettings = AppAppearanceSettings.defaults,
    this.hasCompletedInitialSetup = false,
  });

  final DashboardService dashboardService;
  final AppUpdateService appUpdateService;
  final UpdateReminderStore updateReminderStore;
  final DashboardSnapshotStore dashboardSnapshotStore;
  final ThemePreferenceStore themePreferenceStore;
  final OnboardingPreferenceStore onboardingPreferenceStore;
  final WorkdayStartStore workdayStartStore;
  final SupportTicketStore supportTicketStore;
  final AccountService? accountService;
  final RemotePushRegistrationService? remotePushRegistrationService;
  final AccountSession? initialAccountSession;
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
  void dispose() {
    unawaited(widget.remotePushRegistrationService?.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final safeTextScale = _appearanceSettings.textScale.clamp(0.8, 1.5);

    return MaterialApp(
      title: 'Work Hours Platform',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      themeMode: _appearanceSettings.themeMode,
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);
        return MediaQuery(
          data: mediaQuery.copyWith(
            textScaler: TextScaler.linear(safeTextScale),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: HomeScreen(
        dashboardService: widget.dashboardService,
        appUpdateService: widget.appUpdateService,
        updateReminderStore: widget.updateReminderStore,
        dashboardSnapshotStore: widget.dashboardSnapshotStore,
        onboardingPreferenceStore: widget.onboardingPreferenceStore,
        workdayStartStore: widget.workdayStartStore,
        supportTicketStore: widget.supportTicketStore,
        accountService: widget.accountService,
        initialAccountSession: widget.initialAccountSession,
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
    final defaultInkColor = isDark
        ? const Color(0xFFE8F0EF)
        : const Color(0xFF1A2A2A);
    final inkColor = _appearanceSettings.textColor ?? defaultInkColor;
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
    final resolvedFontFamily = _platformFontFamily(_appearanceSettings.fontFamily);
    final baseTextTheme = _applyAppearanceToTextTheme(
      ThemeData(brightness: brightness).textTheme,
      inkColor: inkColor,
      fontFamily: resolvedFontFamily,
    );
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
      fontFamily: resolvedFontFamily,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: canvasColor,
      textTheme: baseTextTheme,
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

  String? _platformFontFamily(AppFontFamily fontFamily) {
    return switch (fontFamily) {
      AppFontFamily.system => null,
      AppFontFamily.sansSerif => switch (defaultTargetPlatform) {
        TargetPlatform.iOS || TargetPlatform.macOS => 'Helvetica Neue',
        TargetPlatform.windows => 'Segoe UI',
        _ => 'sans-serif',
      },
      AppFontFamily.serif => switch (defaultTargetPlatform) {
        TargetPlatform.iOS || TargetPlatform.macOS => 'Times New Roman',
        TargetPlatform.windows => 'Georgia',
        _ => 'serif',
      },
      AppFontFamily.monospace => switch (defaultTargetPlatform) {
        TargetPlatform.iOS || TargetPlatform.macOS => 'Courier',
        TargetPlatform.windows => 'Consolas',
        _ => 'monospace',
      },
      AppFontFamily.rounded => switch (defaultTargetPlatform) {
        TargetPlatform.iOS || TargetPlatform.macOS => 'SF Pro Rounded',
        TargetPlatform.windows => 'Trebuchet MS',
        _ => 'sans-serif',
      },
      AppFontFamily.condensed => switch (defaultTargetPlatform) {
        TargetPlatform.iOS || TargetPlatform.macOS => 'Avenir Next Condensed',
        TargetPlatform.windows => 'Arial Narrow',
        _ => 'sans-serif-condensed',
      },
    };
  }

  TextTheme _applyAppearanceToTextTheme(
    TextTheme textTheme, {
    required Color inkColor,
    required String? fontFamily,
  }) {
    TextStyle? transform(TextStyle? style) {
      if (style == null) {
        return null;
      }

      return style.copyWith(
        color: inkColor,
        fontFamily: fontFamily,
      );
    }

    return textTheme.copyWith(
      displayLarge: transform(textTheme.displayLarge),
      displayMedium: transform(textTheme.displayMedium),
      displaySmall: transform(textTheme.displaySmall),
      headlineLarge: transform(textTheme.headlineLarge),
      headlineMedium: transform(textTheme.headlineMedium),
      headlineSmall: transform(textTheme.headlineSmall),
      titleLarge: transform(textTheme.titleLarge),
      titleMedium: transform(textTheme.titleMedium),
      titleSmall: transform(textTheme.titleSmall),
      bodyLarge: transform(textTheme.bodyLarge),
      bodyMedium: transform(textTheme.bodyMedium),
      bodySmall: transform(textTheme.bodySmall),
      labelLarge: transform(textTheme.labelLarge),
      labelMedium: transform(textTheme.labelMedium),
      labelSmall: transform(textTheme.labelSmall),
    );
  }
}
