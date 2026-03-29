import 'package:work_hours_mobile/domain/models/leave_entry.dart';
import 'package:work_hours_mobile/domain/models/support_ticket.dart';
import 'package:work_hours_mobile/domain/models/user_work_rules.dart';
import 'package:work_hours_mobile/domain/models/weekday_schedule.dart';
import 'package:work_hours_mobile/domain/models/weekday_target_minutes.dart';
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
    required bool useUniformDailyTarget,
    required int dailyTargetMinutes,
    required WeekdayTargetMinutes weekdayTargetMinutes,
    required WeekdaySchedule weekdaySchedule,
    required UserWorkRules workRules,
    required String month,
  }) async {
    await _apiClient.updateProfile(
      fullName: fullName,
      useUniformDailyTarget: useUniformDailyTarget,
      dailyTargetMinutes: dailyTargetMinutes,
      weekdayTargetMinutes: weekdayTargetMinutes,
      weekdaySchedule: weekdaySchedule,
      workRules: workRules,
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

  @override
  Future<DashboardSnapshot> saveScheduleOverride({
    required String date,
    required int targetMinutes,
    String? startTime,
    String? endTime,
    required int breakMinutes,
    String? note,
    required String month,
  }) async {
    await _apiClient.createScheduleOverride(
      date: date,
      targetMinutes: targetMinutes,
      startTime: startTime,
      endTime: endTime,
      breakMinutes: breakMinutes,
      note: note,
    );
    return _buildSnapshot(month: month);
  }

  @override
  Future<DashboardSnapshot> removeScheduleOverride({
    required String date,
    required String month,
  }) async {
    await _apiClient.deleteScheduleOverride(date: date);
    return _buildSnapshot(month: month);
  }

  @override
  Future<SupportTicketThread> submitSupportTicket({
    required SupportTicketCategory category,
    String? name,
    String? email,
    required String subject,
    required String message,
    String? appVersion,
    String? clientLogs,
    List<SupportTicketUploadAttachment> attachments = const [],
  }) {
    return _apiClient.createSupportTicket(
      category: category,
      name: name,
      email: email,
      subject: subject,
      message: message,
      appVersion: appVersion,
      clientLogs: clientLogs,
      attachments: attachments,
    );
  }

  @override
  Future<SupportTicketThread> fetchSupportTicket({required String ticketId}) {
    return _apiClient.fetchSupportTicket(ticketId: ticketId);
  }

  @override
  Future<SupportTicketThread> replyToSupportTicket({
    required String ticketId,
    required String message,
  }) {
    return _apiClient.replyToSupportTicket(
      ticketId: ticketId,
      message: message,
    );
  }

  Future<DashboardSnapshot> _buildSnapshot({required String month}) async {
    final profileFuture = _apiClient.fetchProfile();
    final summaryFuture = _apiClient.fetchMonthlySummary(month: month);
    final workEntriesFuture = _apiClient.fetchWorkEntries(month: month);
    final leaveEntriesFuture = _apiClient.fetchLeaveEntries(month: month);
    final scheduleOverridesFuture = _apiClient.fetchScheduleOverrides(
      month: month,
    );

    final profile = await profileFuture;
    final summary = (await summaryFuture).applyingRules(profile.workRules);
    final workEntries = await workEntriesFuture;
    final leaveEntries = await leaveEntriesFuture;
    final scheduleOverrides = await scheduleOverridesFuture;

    return DashboardSnapshot(
      profile: profile,
      summary: summary,
      workEntries: workEntries.reversed.toList(growable: false),
      leaveEntries: leaveEntries.reversed.toList(growable: false),
      scheduleOverrides: scheduleOverrides.reversed.toList(growable: false),
      apiBaseUrl: _apiClient.baseUrl,
    );
  }
}
