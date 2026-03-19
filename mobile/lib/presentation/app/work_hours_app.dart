import 'package:flutter/material.dart';
import 'package:work_hours_mobile/application/services/app_update_service.dart';
import 'package:work_hours_mobile/application/services/dashboard_service.dart';
import 'package:work_hours_mobile/presentation/home/home_screen.dart';

class WorkHoursApp extends StatelessWidget {
  const WorkHoursApp({
    super.key,
    required this.dashboardService,
    required this.appUpdateService,
  });

  final DashboardService dashboardService;
  final AppUpdateService appUpdateService;

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
        useMaterial3: true,
      ),
      home: HomeScreen(
        dashboardService: dashboardService,
        appUpdateService: appUpdateService,
      ),
    );
  }
}
