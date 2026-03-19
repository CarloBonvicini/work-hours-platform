import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_hours_mobile/application/services/app_update_service.dart';
import 'package:work_hours_mobile/application/services/dashboard_service.dart';
import 'package:work_hours_mobile/application/services/onboarding_preference_store.dart';
import 'package:work_hours_mobile/application/services/theme_preference_store.dart';
import 'package:work_hours_mobile/application/services/update_launcher.dart';
import 'package:work_hours_mobile/application/services/update_reminder_store.dart';
import 'package:work_hours_mobile/domain/models/app_update.dart';
import 'package:work_hours_mobile/domain/models/dashboard_snapshot.dart';
import 'package:work_hours_mobile/domain/models/leave_entry.dart';
import 'package:work_hours_mobile/domain/models/monthly_summary.dart';
import 'package:work_hours_mobile/domain/models/profile.dart';
import 'package:work_hours_mobile/domain/models/schedule_override.dart';
import 'package:work_hours_mobile/domain/models/support_ticket.dart';
import 'package:work_hours_mobile/domain/models/weekday_target_minutes.dart';
import 'package:work_hours_mobile/domain/models/work_entry.dart';
import 'package:work_hours_mobile/domain/repositories/dashboard_repository.dart';
import 'package:work_hours_mobile/presentation/app/work_hours_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('shows simplified dashboard flow', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 2200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      WorkHoursApp(
        dashboardService: DashboardService(
          repository: _FakeDashboardRepository(),
        ),
        appUpdateService: _FakeAppUpdateService(),
        updateReminderStore: _FakeUpdateReminderStore(),
        onboardingPreferenceStore: _FakeOnboardingPreferenceStore(
          hasCompleted: true,
        ),
        themePreferenceStore: _FakeThemePreferenceStore(),
        hasCompletedInitialSetup: true,
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Ciao Carlo Bonvicini'), findsOneWidget);
    expect(find.textContaining('Backend collegato'), findsOneWidget);
    expect(find.text('Sezioni'), findsOneWidget);
    expect(find.text('Panoramica del mese'), findsOneWidget);
    expect(find.text('Aggiornamento disponibile'), findsOneWidget);
    expect(find.text('Ricordamelo piu tardi'), findsOneWidget);
    expect(find.text('Aggiorna'), findsNothing);

    await tester.tap(find.text('Ricordamelo piu tardi'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('home-section-calendar')));
    await tester.pumpAndSettle();

    expect(find.text('Calendario'), findsWidgets);
    expect(find.text('Panoramica del mese'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('calendar-day-2026-03-04')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Selezionato: 4 marzo 2026'), findsOneWidget);
  });

  testWidgets('checks for updates again when app resumes', (tester) async {
    final appUpdateService = _CountingAppUpdateService();

    await tester.pumpWidget(
      WorkHoursApp(
        dashboardService: DashboardService(
          repository: _FakeDashboardRepository(),
        ),
        appUpdateService: appUpdateService,
        updateReminderStore: _FakeUpdateReminderStore(),
        onboardingPreferenceStore: _FakeOnboardingPreferenceStore(
          hasCompleted: true,
        ),
        themePreferenceStore: _FakeThemePreferenceStore(),
        hasCompletedInitialSetup: true,
      ),
    );

    await tester.pumpAndSettle();
    expect(appUpdateService.checkCount, 1);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(appUpdateService.checkCount, 2);
  });

  testWidgets('snoozes update dialog when user chooses later', (tester) async {
    final reminderStore = _FakeUpdateReminderStore();

    await tester.pumpWidget(
      WorkHoursApp(
        dashboardService: DashboardService(
          repository: _FakeDashboardRepository(),
        ),
        appUpdateService: _FakeAppUpdateService(),
        updateReminderStore: reminderStore,
        onboardingPreferenceStore: _FakeOnboardingPreferenceStore(
          hasCompleted: true,
        ),
        themePreferenceStore: _FakeThemePreferenceStore(),
        hasCompletedInitialSetup: true,
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('Ricordamelo piu tardi'));
    await tester.pumpAndSettle();

    expect(reminderStore.remindedLaterVersions, ['0.1.1']);
    expect(find.text('Aggiornamento disponibile'), findsNothing);
  });

  testWidgets('toggles dark theme from settings', (tester) async {
    final themePreferenceStore = _FakeThemePreferenceStore();

    await tester.pumpWidget(
      WorkHoursApp(
        dashboardService: DashboardService(
          repository: _FakeDashboardRepository(),
        ),
        appUpdateService: _CountingAppUpdateService(),
        updateReminderStore: _FakeUpdateReminderStore(),
        onboardingPreferenceStore: _FakeOnboardingPreferenceStore(
          hasCompleted: true,
        ),
        themePreferenceStore: themePreferenceStore,
        hasCompletedInitialSetup: true,
      ),
    );

    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('home-section-profile')),
    );
    await tester.tap(find.byKey(const ValueKey('home-section-profile')));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('dark-theme-switch')),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('dark-theme-switch')));
    await tester.pumpAndSettle();

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.dark);
    expect(themePreferenceStore.savedThemeModes, [ThemeMode.dark]);
  });

  testWidgets('shows initial setup wizard only on first launch', (
    tester,
  ) async {
    final onboardingStore = _FakeOnboardingPreferenceStore(hasCompleted: false);
    final themePreferenceStore = _FakeThemePreferenceStore();
    final repository = _FakeDashboardRepository();

    await tester.pumpWidget(
      WorkHoursApp(
        dashboardService: DashboardService(repository: repository),
        appUpdateService: _CountingAppUpdateService(),
        updateReminderStore: _FakeUpdateReminderStore(),
        onboardingPreferenceStore: onboardingStore,
        themePreferenceStore: themePreferenceStore,
        hasCompletedInitialSetup: false,
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Configurazione iniziale 1/3'), findsOneWidget);
    await tester.tap(find.text('Scuro'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continua'));
    await tester.pumpAndSettle();

    expect(find.text('Configurazione iniziale 2/3'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Carlo');
    await tester.tap(find.text('Continua'));
    await tester.pumpAndSettle();

    expect(find.text('Configurazione iniziale 3/3'), findsOneWidget);
    await tester.tap(find.text('Stesse ore ogni giorno lavorativo'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
    await tester.enterText(find.byType(TextField), '7,30');
    await tester.tap(find.text('Inizia'));
    await tester.pumpAndSettle();

    expect(find.text('Configurazione iniziale 1/3'), findsNothing);
    expect(onboardingStore.markCompletedCalls, 1);
    expect(themePreferenceStore.savedThemeModes, [ThemeMode.dark]);
    expect(repository.savedFullName, 'Carlo');
    expect(repository.savedDailyTargetMinutes, 450);
  });

  testWidgets('submits a support ticket from the app', (tester) async {
    final repository = _FakeDashboardRepository();
    await tester.binding.setSurfaceSize(const Size(1400, 2200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      WorkHoursApp(
        dashboardService: DashboardService(repository: repository),
        appUpdateService: _CountingAppUpdateService(),
        updateReminderStore: _FakeUpdateReminderStore(),
        onboardingPreferenceStore: _FakeOnboardingPreferenceStore(
          hasCompleted: true,
        ),
        themePreferenceStore: _FakeThemePreferenceStore(),
        hasCompletedInitialSetup: true,
      ),
    );

    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('home-section-ticket')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('home-section-ticket')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('ticket-category-feature')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('ticket-subject-field')),
      'Vista mensile migliore',
    );
    await tester.enterText(
      find.byKey(const ValueKey('ticket-message-field')),
      'Vorrei una vista del calendario piu leggibile.',
    );
    await tester.tap(find.byKey(const ValueKey('ticket-submit-button')));
    await tester.pumpAndSettle();

    expect(repository.submittedTicketCategory, SupportTicketCategory.feature);
    expect(repository.submittedTicketSubject, 'Vista mensile migliore');
    expect(
      repository.submittedTicketMessage,
      'Vorrei una vista del calendario piu leggibile.',
    );
  });
}

class _FakeAppUpdateService implements AppUpdateService {
  @override
  Future<AppUpdate?> checkForUpdate() async {
    return const AppUpdate(
      currentVersion: '0.1.0',
      latestVersion: '0.1.1',
      downloadUrl: 'https://example.invalid/app-release.apk',
      releasePageUrl: 'https://example.invalid/releases/latest',
    );
  }

  @override
  Future<bool> openUpdate(AppUpdate update) async {
    return true;
  }

  @override
  Future<DownloadedAppUpdate> downloadUpdate(
    AppUpdate update, {
    required UpdateDownloadProgressCallback onProgress,
  }) async {
    onProgress(const UpdateDownloadProgress(receivedBytes: 10, totalBytes: 10));
    return DownloadedAppUpdate(
      update: update,
      filePath: '/tmp/app-release.apk',
      fileName: 'app-release.apk',
      bytesDownloaded: 10,
    );
  }

  @override
  Future<UpdateInstallResult> installUpdate(DownloadedAppUpdate update) async {
    return UpdateInstallResult.started;
  }
}

class _CountingAppUpdateService implements AppUpdateService {
  int checkCount = 0;

  @override
  Future<AppUpdate?> checkForUpdate() async {
    checkCount += 1;
    return null;
  }

  @override
  Future<bool> openUpdate(AppUpdate update) async {
    return true;
  }

  @override
  Future<DownloadedAppUpdate> downloadUpdate(
    AppUpdate update, {
    required UpdateDownloadProgressCallback onProgress,
  }) async {
    onProgress(const UpdateDownloadProgress(receivedBytes: 10, totalBytes: 10));
    return DownloadedAppUpdate(
      update: update,
      filePath: '/tmp/app-release.apk',
      fileName: 'app-release.apk',
      bytesDownloaded: 10,
    );
  }

  @override
  Future<UpdateInstallResult> installUpdate(DownloadedAppUpdate update) async {
    return UpdateInstallResult.started;
  }
}

class _FakeUpdateReminderStore implements UpdateReminderStore {
  final List<String> remindedLaterVersions = [];
  final List<String> deferredAfterOpeningVersions = [];

  @override
  Future<void> deferAfterOpening(AppUpdate update) async {
    deferredAfterOpeningVersions.add(update.latestVersion);
  }

  @override
  Future<void> remindLater(AppUpdate update) async {
    remindedLaterVersions.add(update.latestVersion);
  }

  @override
  Future<bool> shouldPromptFor(AppUpdate update) async {
    return true;
  }
}

class _FakeThemePreferenceStore implements ThemePreferenceStore {
  final List<ThemeMode> savedThemeModes = [];

  @override
  Future<ThemeMode> loadThemeMode() async {
    return ThemeMode.light;
  }

  @override
  Future<void> saveThemeMode(ThemeMode themeMode) async {
    savedThemeModes.add(themeMode);
  }
}

class _FakeOnboardingPreferenceStore implements OnboardingPreferenceStore {
  _FakeOnboardingPreferenceStore({required this.hasCompleted});

  final bool hasCompleted;
  int markCompletedCalls = 0;

  @override
  Future<bool> hasCompletedInitialSetup() async {
    return hasCompleted;
  }

  @override
  Future<void> markInitialSetupCompleted() async {
    markCompletedCalls += 1;
  }
}

class _FakeDashboardRepository implements DashboardRepository {
  String? savedFullName;
  int? savedDailyTargetMinutes;
  WeekdayTargetMinutes? savedWeekdayTargetMinutes;
  SupportTicketCategory? submittedTicketCategory;
  String? submittedTicketName;
  String? submittedTicketEmail;
  String? submittedTicketSubject;
  String? submittedTicketMessage;
  String? submittedTicketAppVersion;

  @override
  Future<DashboardSnapshot> addLeaveEntry({
    required String date,
    required int minutes,
    required LeaveType type,
    String? note,
    required String month,
  }) {
    return loadSnapshot(month: month);
  }

  @override
  Future<DashboardSnapshot> addWorkEntry({
    required String date,
    required int minutes,
    String? note,
    required String month,
  }) {
    return loadSnapshot(month: month);
  }

  @override
  Future<DashboardSnapshot> loadSnapshot({required String month}) async {
    return DashboardSnapshot(
      profile: const UserProfile(
        id: 'default-profile',
        fullName: 'Carlo Bonvicini',
        useUniformDailyTarget: false,
        dailyTargetMinutes: 450,
        weekdayTargetMinutes: WeekdayTargetMinutes(
          monday: 480,
          tuesday: 360,
          wednesday: 360,
          thursday: 480,
          friday: 480,
          saturday: 0,
          sunday: 0,
        ),
      ),
      summary: const MonthlySummary(
        month: '2026-03',
        expectedMinutes: 10350,
        workedMinutes: 900,
        leaveMinutes: 60,
        balanceMinutes: -9390,
      ),
      workEntries: const [
        WorkEntry(
          id: '1',
          date: '2026-03-03',
          minutes: 420,
          note: 'Sprint mobile',
        ),
      ],
      leaveEntries: const [
        LeaveEntry(
          id: 'leave-1',
          date: '2026-03-04',
          minutes: 60,
          type: LeaveType.permit,
          note: 'Visita medica',
        ),
      ],
      scheduleOverrides: const [
        ScheduleOverride(
          id: 'override-1',
          date: '2026-03-04',
          targetMinutes: 240,
          note: 'Scambio turno',
        ),
      ],
      apiBaseUrl: 'http://localhost:8080/',
    );
  }

  @override
  Future<DashboardSnapshot> saveProfile({
    required String fullName,
    required bool useUniformDailyTarget,
    required int dailyTargetMinutes,
    required WeekdayTargetMinutes weekdayTargetMinutes,
    required String month,
  }) {
    savedFullName = fullName;
    savedDailyTargetMinutes = dailyTargetMinutes;
    savedWeekdayTargetMinutes = weekdayTargetMinutes;
    return loadSnapshot(month: month);
  }

  @override
  Future<DashboardSnapshot> saveScheduleOverride({
    required String date,
    required int targetMinutes,
    String? note,
    required String month,
  }) {
    return loadSnapshot(month: month);
  }

  @override
  Future<DashboardSnapshot> removeScheduleOverride({
    required String date,
    required String month,
  }) {
    return loadSnapshot(month: month);
  }

  @override
  Future<void> submitSupportTicket({
    required SupportTicketCategory category,
    String? name,
    String? email,
    required String subject,
    required String message,
    String? appVersion,
  }) async {
    submittedTicketCategory = category;
    submittedTicketName = name;
    submittedTicketEmail = email;
    submittedTicketSubject = subject;
    submittedTicketMessage = message;
    submittedTicketAppVersion = appVersion;
  }
}
