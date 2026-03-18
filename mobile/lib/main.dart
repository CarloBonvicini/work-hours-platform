import 'package:flutter/material.dart';
import 'package:work_hours_mobile/application/services/dashboard_service.dart';
import 'package:work_hours_mobile/data/repositories/in_memory_dashboard_repository.dart';
import 'package:work_hours_mobile/presentation/app/work_hours_app.dart';

void main() {
  final dashboardService = DashboardService(
    repository: InMemoryDashboardRepository(),
  );

  runApp(WorkHoursApp(dashboardService: dashboardService));
}
