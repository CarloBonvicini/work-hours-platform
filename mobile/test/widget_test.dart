import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_hours_mobile/application/services/app_update_service.dart';
import 'package:work_hours_mobile/application/services/dashboard_service.dart';
import 'package:work_hours_mobile/application/services/theme_preference_store.dart';
import 'package:work_hours_mobile/application/services/update_reminder_store.dart';
import 'package:work_hours_mobile/domain/models/app_update.dart';
import 'package:work_hours_mobile/domain/models/dashboard_snapshot.dart';
import 'package:work_hours_mobile/domain/models/leave_entry.dart';
import 'package:work_hours_mobile/domain/models/monthly_summary.dart';
import 'package:work_hours_mobile/domain/models/profile.dart';
import 'package:work_hours_mobile/domain/models/schedule_override.dart';
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
        themePreferenceStore: _FakeThemePreferenceStore(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Ciao Carlo Bonvicini'), findsOneWidget);
    expect(find.textContaining('Backend collegato'), findsOneWidget);
    expect(find.text('Panoramica del mese'), findsOneWidget);
    expect(find.text('Calendario'), findsOneWidget);
    expect(find.text('Aggiornamento disponibile'), findsOneWidget);
    expect(find.text('Ricordamelo piu tardi'), findsOneWidget);

    await tester.tap(find.text('Ricordamelo piu tardi'));
    await tester.pumpAndSettle();

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
        themePreferenceStore: _FakeThemePreferenceStore(),
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
        themePreferenceStore: _FakeThemePreferenceStore(),
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
        themePreferenceStore: themePreferenceStore,
      ),
    );

    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('dark-theme-switch')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('dark-theme-switch')));
    await tester.pumpAndSettle();

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.dark);
    expect(themePreferenceStore.savedThemeModes, [ThemeMode.dark]);
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

class _FakeDashboardRepository implements DashboardRepository {
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
}
