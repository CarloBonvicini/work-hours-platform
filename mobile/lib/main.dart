import 'package:work_hours_mobile/application/services/account_service.dart';
import 'package:work_hours_mobile/application/services/account_session_store.dart';
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
import 'package:work_hours_mobile/data/repositories/local_dashboard_repository.dart';
import 'package:work_hours_mobile/dev/ui_demo_dashboard_repository.dart';
import 'package:work_hours_mobile/dev/ui_demo_update_service.dart';
import 'package:work_hours_mobile/domain/models/cloud_backup_bundle.dart';
import 'package:work_hours_mobile/presentation/app/work_hours_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const appMode = String.fromEnvironment('APP_MODE', defaultValue: 'api');
  const isUiDemoMode = appMode == 'ui_demo';
  final apiConfig = WorkHoursApiConfig.fromEnvironment();
  final releaseFeedConfig = ReleaseFeedConfig.fromEnvironment();
  final apiClient = WorkHoursApiClient(baseUrl: apiConfig.baseUrl);
  final localRepository = SharedPreferencesLocalDashboardRepository(
    ticketApiClient: apiClient,
  );
  const accountSessionStore = SharedPreferencesAccountSessionStore();
  final dashboardService = DashboardService(
    repository: isUiDemoMode
        ? UiDemoDashboardRepository()
        : localRepository,
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
  final accountService = isUiDemoMode
      ? null
      : AccountService(
          baseUrl: apiConfig.baseUrl,
          sessionStore: accountSessionStore,
          localRepository: localRepository,
          themePreferenceStore: themePreferenceStore,
        );

  if (!isUiDemoMode) {
    await _migrateLegacyApiDataIfNeeded(
      repository: localRepository,
      apiClient: apiClient,
    );
  }

  final initialAccountSession = isUiDemoMode
      ? null
      : await accountSessionStore.loadSession();
  if (!isUiDemoMode &&
      initialAccountSession != null &&
      await localRepository.isEmpty()) {
    final restored = await accountService!.restoreFromCloud(
      session: initialAccountSession,
    );
    if (restored.bundle != null) {
      await themePreferenceStore.saveAppearanceSettings(
        restored.bundle!.appearanceSettings,
      );
    }
  }
  final resolvedAppearanceSettings = await themePreferenceStore
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
      accountService: accountService,
      initialAccountSession: initialAccountSession,
      initialAppearanceSettings: resolvedAppearanceSettings,
      hasCompletedInitialSetup: hasCompletedInitialSetup,
    ),
  );
}

Future<void> _migrateLegacyApiDataIfNeeded({
  required SharedPreferencesLocalDashboardRepository repository,
  required WorkHoursApiClient apiClient,
}) async {
  if (await repository.hasCompletedLegacyMigration()) {
    return;
  }

  try {
    final profileFuture = apiClient.fetchProfile();
    final workEntriesFuture = apiClient.fetchWorkEntries();
    final leaveEntriesFuture = apiClient.fetchLeaveEntries();
    final overridesFuture = apiClient.fetchScheduleOverrides();

    final profile = await profileFuture;
    final workEntries = await workEntriesFuture;
    final leaveEntries = await leaveEntriesFuture;
    final scheduleOverrides = await overridesFuture;

    final hasAnyLegacyData =
        profile.fullName.trim().isNotEmpty &&
        (profile.fullName != 'Utente' ||
            workEntries.isNotEmpty ||
            leaveEntries.isNotEmpty ||
            scheduleOverrides.isNotEmpty);

    if (hasAnyLegacyData && await repository.isEmpty()) {
      await repository.importBundle(
        LocalDashboardDataBundle(
          profile: profile,
          workEntries: workEntries,
          leaveEntries: leaveEntries,
          scheduleOverrides: scheduleOverrides,
        ),
      );
    }

    await repository.markLegacyMigrationCompleted();
  } catch (_) {
    // Legacy migration is best-effort. Local-first mode must still start.
  }
}
