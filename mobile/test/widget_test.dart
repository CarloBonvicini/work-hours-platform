import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_hours_mobile/application/services/app_update_service.dart';
import 'package:work_hours_mobile/application/services/dashboard_service.dart';
import 'package:work_hours_mobile/domain/models/app_update.dart';
import 'package:work_hours_mobile/domain/models/dashboard_snapshot.dart';
import 'package:work_hours_mobile/domain/models/monthly_summary.dart';
import 'package:work_hours_mobile/domain/models/profile.dart';
import 'package:work_hours_mobile/domain/models/work_entry.dart';
import 'package:work_hours_mobile/domain/repositories/dashboard_repository.dart';
import 'package:work_hours_mobile/presentation/app/work_hours_app.dart';

void main() {
  testWidgets('shows connected dashboard and forms', (tester) async {
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

    expect(find.text('Work Hours Platform'), findsOneWidget);
    expect(find.textContaining('Backend collegato'), findsOneWidget);
    expect(find.text('Profilo'), findsOneWidget);
    expect(find.text('Inserisci ore'), findsOneWidget);
    expect(find.text('Salva profilo'), findsOneWidget);
    expect(find.text('Registra ore'), findsOneWidget);
    expect(find.text('Aggiornamento disponibile'), findsOneWidget);
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

class _FakeDashboardRepository implements DashboardRepository {
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
        dailyTargetMinutes: 450,
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
      apiBaseUrl: 'http://localhost:8080/',
    );
  }

  @override
  Future<DashboardSnapshot> saveProfile({
    required String fullName,
    required int dailyTargetMinutes,
    required String month,
  }) {
    return loadSnapshot(month: month);
  }
}
