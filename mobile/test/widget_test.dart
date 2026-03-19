import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_hours_mobile/application/services/app_update_service.dart';
import 'package:work_hours_mobile/application/services/dashboard_service.dart';
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
  testWidgets('shows simplified dashboard flow', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 2200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      WorkHoursApp(
        dashboardService: DashboardService(
          repository: _FakeDashboardRepository(),
        ),
        appUpdateService: _FakeAppUpdateService(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Ciao Carlo Bonvicini'), findsOneWidget);
    expect(find.textContaining('Backend collegato'), findsOneWidget);
    expect(find.text('Panoramica del mese'), findsOneWidget);
    expect(find.text('Calendario'), findsOneWidget);
    expect(find.text('Aggiornamento disponibile'), findsOneWidget);

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
      ),
    );

    await tester.pumpAndSettle();
    expect(appUpdateService.checkCount, 1);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(appUpdateService.checkCount, 2);
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
