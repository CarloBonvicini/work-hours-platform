import 'package:work_hours_mobile/application/services/app_update_service.dart';
import 'package:flutter/material.dart';
import 'package:work_hours_mobile/application/services/dashboard_service.dart';
import 'package:work_hours_mobile/application/services/dashboard_snapshot_store.dart';
import 'package:work_hours_mobile/application/services/onboarding_preference_store.dart';
import 'package:work_hours_mobile/application/services/theme_preference_store.dart';
import 'package:work_hours_mobile/application/services/update_reminder_store.dart';
import 'package:work_hours_mobile/application/services/update_launcher.dart';
import 'package:work_hours_mobile/application/services/workday_start_store.dart';
import 'package:work_hours_mobile/data/api/github_release_client.dart';
import 'package:work_hours_mobile/data/api/release_feed_config.dart';
import 'package:work_hours_mobile/data/api/work_hours_api_client.dart';
import 'package:work_hours_mobile/data/api/work_hours_api_config.dart';
import 'package:work_hours_mobile/data/repositories/api_dashboard_repository.dart';
import 'package:work_hours_mobile/dev/ui_demo_dashboard_repository.dart';
import 'package:work_hours_mobile/dev/ui_demo_update_service.dart';
import 'package:work_hours_mobile/presentation/app/work_hours_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const appMode = String.fromEnvironment('APP_MODE', defaultValue: 'api');
  const isUiDemoMode = appMode == 'ui_demo';
  final apiConfig = WorkHoursApiConfig.fromEnvironment();
  final releaseFeedConfig = ReleaseFeedConfig.fromEnvironment();
  final dashboardService = DashboardService(
    repository: isUiDemoMode
        ? UiDemoDashboardRepository()
        : ApiDashboardRepository(
            apiClient: WorkHoursApiClient(baseUrl: apiConfig.baseUrl),
          ),
  );
  final appUpdateService = isUiDemoMode
      ? const UiDemoAppUpdateService()
      : ReleaseAppUpdateService(
          releaseClient: GitHubReleaseClient(
            latestReleaseApiUrl: releaseFeedConfig.latestReleaseApiUrl,
            fallbackReleasePageUrl: releaseFeedConfig.releasePageUrl,
          ),
          updateLauncher: const PlatformUpdateLauncher(),
        );
  const updateReminderStore = SharedPreferencesUpdateReminderStore();
  const dashboardSnapshotStore = SharedPreferencesDashboardSnapshotStore();
  const themePreferenceStore = SharedPreferencesThemePreferenceStore();
  const onboardingPreferenceStore =
      SharedPreferencesOnboardingPreferenceStore();
  const workdayStartStore = SharedPreferencesWorkdayStartStore();
  final initialAppearanceSettings = await themePreferenceStore
      .loadAppearanceSettings();
  final hasCompletedInitialSetup = isUiDemoMode
      ? true
      : await onboardingPreferenceStore.hasCompletedInitialSetup();

  runApp(
    WorkHoursApp(
      dashboardService: dashboardService,
      appUpdateService: appUpdateService,
      updateReminderStore: updateReminderStore,
      dashboardSnapshotStore: dashboardSnapshotStore,
      themePreferenceStore: themePreferenceStore,
      onboardingPreferenceStore: onboardingPreferenceStore,
      workdayStartStore: workdayStartStore,
      initialAppearanceSettings: initialAppearanceSettings,
      hasCompletedInitialSetup: hasCompletedInitialSetup,
    ),
  );
}
