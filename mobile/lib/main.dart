import 'package:work_hours_mobile/application/services/app_update_service.dart';
import 'package:flutter/material.dart';
import 'package:work_hours_mobile/application/services/dashboard_service.dart';
import 'package:work_hours_mobile/application/services/update_reminder_store.dart';
import 'package:work_hours_mobile/application/services/update_launcher.dart';
import 'package:work_hours_mobile/data/api/github_release_client.dart';
import 'package:work_hours_mobile/data/api/release_feed_config.dart';
import 'package:work_hours_mobile/data/api/work_hours_api_client.dart';
import 'package:work_hours_mobile/data/api/work_hours_api_config.dart';
import 'package:work_hours_mobile/data/repositories/api_dashboard_repository.dart';
import 'package:work_hours_mobile/presentation/app/work_hours_app.dart';

void main() {
  final apiConfig = WorkHoursApiConfig.fromEnvironment();
  final releaseFeedConfig = ReleaseFeedConfig.fromEnvironment();
  final dashboardService = DashboardService(
    repository: ApiDashboardRepository(
      apiClient: WorkHoursApiClient(baseUrl: apiConfig.baseUrl),
    ),
  );
  final appUpdateService = ReleaseAppUpdateService(
    releaseClient: GitHubReleaseClient(
      latestReleaseApiUrl: releaseFeedConfig.latestReleaseApiUrl,
      fallbackReleasePageUrl: releaseFeedConfig.releasePageUrl,
    ),
    updateLauncher: const PlatformUpdateLauncher(),
  );
  const updateReminderStore = SharedPreferencesUpdateReminderStore();

  runApp(
    WorkHoursApp(
      dashboardService: dashboardService,
      appUpdateService: appUpdateService,
      updateReminderStore: updateReminderStore,
    ),
  );
}
