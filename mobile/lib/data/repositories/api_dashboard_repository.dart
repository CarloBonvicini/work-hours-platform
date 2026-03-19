import 'package:work_hours_mobile/domain/models/leave_entry.dart';
import 'package:work_hours_mobile/data/api/work_hours_api_client.dart';
import 'package:work_hours_mobile/domain/models/dashboard_snapshot.dart';
import 'package:work_hours_mobile/domain/repositories/dashboard_repository.dart';

class ApiDashboardRepository implements DashboardRepository {
  ApiDashboardRepository({required WorkHoursApiClient apiClient})
    : _apiClient = apiClient;

  final WorkHoursApiClient _apiClient;

  @override
  Future<DashboardSnapshot> loadSnapshot({required String month}) async {
    return _buildSnapshot(month: month);
  }

  @override
  Future<DashboardSnapshot> saveProfile({
    required String fullName,
    required int dailyTargetMinutes,
    required String month,
  }) async {
    await _apiClient.updateProfile(
      fullName: fullName,
      dailyTargetMinutes: dailyTargetMinutes,
    );

    return _buildSnapshot(month: month);
  }

  @override
  Future<DashboardSnapshot> addWorkEntry({
    required String date,
    required int minutes,
    String? note,
    required String month,
  }) async {
    await _apiClient.createWorkEntry(date: date, minutes: minutes, note: note);
    return _buildSnapshot(month: month);
  }

  @override
  Future<DashboardSnapshot> addLeaveEntry({
    required String date,
    required int minutes,
    required LeaveType type,
    String? note,
    required String month,
  }) async {
    await _apiClient.createLeaveEntry(
      date: date,
      minutes: minutes,
      type: type,
      note: note,
    );
    return _buildSnapshot(month: month);
  }

  Future<DashboardSnapshot> _buildSnapshot({required String month}) async {
    final profileFuture = _apiClient.fetchProfile();
    final summaryFuture = _apiClient.fetchMonthlySummary(month: month);
    final workEntriesFuture = _apiClient.fetchWorkEntries(month: month);
    final leaveEntriesFuture = _apiClient.fetchLeaveEntries(month: month);

    final profile = await profileFuture;
    final summary = await summaryFuture;
    final workEntries = await workEntriesFuture;
    final leaveEntries = await leaveEntriesFuture;

    return DashboardSnapshot(
      profile: profile,
      summary: summary,
      workEntries: workEntries.reversed.toList(growable: false),
      leaveEntries: leaveEntries.reversed.toList(growable: false),
      apiBaseUrl: _apiClient.baseUrl,
    );
  }
}
