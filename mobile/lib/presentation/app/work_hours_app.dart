import 'package:flutter/material.dart';
import 'package:work_hours_mobile/application/services/app_update_service.dart';
import 'package:work_hours_mobile/application/services/dashboard_service.dart';
import 'package:work_hours_mobile/application/services/update_reminder_store.dart';
import 'package:work_hours_mobile/presentation/home/home_screen.dart';

class WorkHoursApp extends StatelessWidget {
  const WorkHoursApp({
    super.key,
    required this.dashboardService,
    required this.appUpdateService,
    required this.updateReminderStore,
  });

  final DashboardService dashboardService;
  final AppUpdateService appUpdateService;
  final UpdateReminderStore updateReminderStore;

  @override
  Widget build(BuildContext context) {
    const canvasColor = Color(0xFFF5F1E8);
    const inkColor = Color(0xFF1A2A2A);
    const accentColor = Color(0xFF0B6E69);

    return MaterialApp(
      title: 'Work Hours Platform',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: accentColor,
          brightness: Brightness.light,
          surface: canvasColor,
        ),
        scaffoldBackgroundColor: canvasColor,
        textTheme: ThemeData.light().textTheme.apply(
          bodyColor: inkColor,
          displayColor: inkColor,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: Color(0xFFD8CEC0)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: Color(0xFFD8CEC0)),
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
          selectedColor: const Color(0xFFDCEFE8),
          backgroundColor: Colors.white,
          side: const BorderSide(color: Color(0xFFD8CEC0)),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        useMaterial3: true,
      ),
      home: HomeScreen(
        dashboardService: dashboardService,
        appUpdateService: appUpdateService,
        updateReminderStore: updateReminderStore,
      ),
    );
  }
}
