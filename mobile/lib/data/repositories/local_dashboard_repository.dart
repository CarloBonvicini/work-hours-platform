import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:work_hours_mobile/domain/models/cloud_backup_bundle.dart';
import 'package:work_hours_mobile/domain/models/dashboard_snapshot.dart';
import 'package:work_hours_mobile/domain/models/day_schedule.dart';
import 'package:work_hours_mobile/domain/models/leave_entry.dart';
import 'package:work_hours_mobile/domain/models/monthly_summary.dart';
import 'package:work_hours_mobile/domain/models/profile.dart';
import 'package:work_hours_mobile/domain/models/schedule_override.dart';
import 'package:work_hours_mobile/domain/models/support_ticket.dart';
import 'package:work_hours_mobile/domain/models/weekday_schedule.dart';
import 'package:work_hours_mobile/domain/models/weekday_target_minutes.dart';
import 'package:work_hours_mobile/domain/models/work_entry.dart';
import 'package:work_hours_mobile/domain/repositories/dashboard_repository.dart';
import 'package:work_hours_mobile/data/api/work_hours_api_client.dart';

class SharedPreferencesLocalDashboardRepository implements DashboardRepository {
  SharedPreferencesLocalDashboardRepository({WorkHoursApiClient? ticketApiClient})
    : _ticketApiClient = ticketApiClient;

  static const _bundleKey = 'local_dashboard.bundle';
  static const _migrationKey = 'local_dashboard.legacy_migrated';

  final WorkHoursApiClient? _ticketApiClient;

  Future<bool> isEmpty() async {
    final bundle = await _loadBundle();
    return bundle == null;
  }

  Future<bool> hasCompletedLegacyMigration() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_migrationKey) ?? false;
  }

  Future<void> markLegacyMigrationCompleted() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_migrationKey, true);
  }

  Future<LocalDashboardDataBundle> exportBundle() async {
    return await _loadBundle() ?? _defaultBundle();
  }

  Future<void> importBundle(LocalDashboardDataBundle bundle) async {
    await _saveBundle(bundle);
  }

  @override
  Future<DashboardSnapshot> loadSnapshot({required String month}) async {
    final bundle = await exportBundle();
    return _buildSnapshot(bundle: bundle, month: month);
  }

  @override
  Future<DashboardSnapshot> saveProfile({
    required String fullName,
    required bool useUniformDailyTarget,
    required int dailyTargetMinutes,
    required WeekdayTargetMinutes weekdayTargetMinutes,
    required WeekdaySchedule weekdaySchedule,
    required String month,
  }) async {
    final currentBundle = await exportBundle();
    final nextBundle = LocalDashboardDataBundle(
      profile: UserProfile(
        id: currentBundle.profile.id,
        fullName: fullName,
        useUniformDailyTarget: useUniformDailyTarget,
        dailyTargetMinutes: dailyTargetMinutes,
        weekdayTargetMinutes: weekdayTargetMinutes,
        weekdaySchedule: weekdaySchedule,
      ),
      workEntries: currentBundle.workEntries,
      leaveEntries: currentBundle.leaveEntries,
      scheduleOverrides: currentBundle.scheduleOverrides,
    );
    await _saveBundle(nextBundle);
    return _buildSnapshot(bundle: nextBundle, month: month);
  }

  @override
  Future<DashboardSnapshot> addWorkEntry({
    required String date,
    required int minutes,
    String? note,
    required String month,
  }) async {
    final currentBundle = await exportBundle();
    final nextBundle = LocalDashboardDataBundle(
      profile: currentBundle.profile,
      workEntries: [
        ...currentBundle.workEntries,
        WorkEntry(
          id: 'work-${DateTime.now().microsecondsSinceEpoch}',
          date: date,
          minutes: minutes,
          note: note,
        ),
      ],
      leaveEntries: currentBundle.leaveEntries,
      scheduleOverrides: currentBundle.scheduleOverrides,
    );
    await _saveBundle(nextBundle);
    return _buildSnapshot(bundle: nextBundle, month: month);
  }

  @override
  Future<DashboardSnapshot> addLeaveEntry({
    required String date,
    required int minutes,
    required LeaveType type,
    String? note,
    required String month,
  }) async {
    final currentBundle = await exportBundle();
    final nextBundle = LocalDashboardDataBundle(
      profile: currentBundle.profile,
      workEntries: currentBundle.workEntries,
      leaveEntries: [
        ...currentBundle.leaveEntries,
        LeaveEntry(
          id: 'leave-${DateTime.now().microsecondsSinceEpoch}',
          date: date,
          minutes: minutes,
          type: type,
          note: note,
        ),
      ],
      scheduleOverrides: currentBundle.scheduleOverrides,
    );
    await _saveBundle(nextBundle);
    return _buildSnapshot(bundle: nextBundle, month: month);
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
    final currentBundle = await exportBundle();
    final nextOverrides = currentBundle.scheduleOverrides
        .where((entry) => entry.date != date)
        .toList(growable: true)
      ..add(
        ScheduleOverride(
          id: 'override-${DateTime.now().microsecondsSinceEpoch}',
          date: date,
          targetMinutes: targetMinutes,
          startTime: startTime,
          endTime: endTime,
          breakMinutes: breakMinutes,
          note: note,
        ),
      );
    final nextBundle = LocalDashboardDataBundle(
      profile: currentBundle.profile,
      workEntries: currentBundle.workEntries,
      leaveEntries: currentBundle.leaveEntries,
      scheduleOverrides: nextOverrides,
    );
    await _saveBundle(nextBundle);
    return _buildSnapshot(bundle: nextBundle, month: month);
  }

  @override
  Future<DashboardSnapshot> removeScheduleOverride({
    required String date,
    required String month,
  }) async {
    final currentBundle = await exportBundle();
    final nextBundle = LocalDashboardDataBundle(
      profile: currentBundle.profile,
      workEntries: currentBundle.workEntries,
      leaveEntries: currentBundle.leaveEntries,
      scheduleOverrides: currentBundle.scheduleOverrides
          .where((entry) => entry.date != date)
          .toList(growable: false),
    );
    await _saveBundle(nextBundle);
    return _buildSnapshot(bundle: nextBundle, month: month);
  }

  @override
  Future<SupportTicketThread> submitSupportTicket({
    required SupportTicketCategory category,
    String? name,
    String? email,
    required String subject,
    required String message,
    String? appVersion,
  }) async {
    final apiClient = _ticketApiClient;
    if (apiClient == null) {
      throw Exception('Ticket non disponibili in locale.');
    }
    return apiClient.createSupportTicket(
      category: category,
      name: name,
      email: email,
      subject: subject,
      message: message,
      appVersion: appVersion,
    );
  }

  @override
  Future<SupportTicketThread> fetchSupportTicket({required String ticketId}) async {
    final apiClient = _ticketApiClient;
    if (apiClient == null) {
      throw Exception('Ticket non disponibili in locale.');
    }
    return apiClient.fetchSupportTicket(ticketId: ticketId);
  }

  @override
  Future<SupportTicketThread> replyToSupportTicket({
    required String ticketId,
    required String message,
  }) async {
    final apiClient = _ticketApiClient;
    if (apiClient == null) {
      throw Exception('Ticket non disponibili in locale.');
    }
    return apiClient.replyToSupportTicket(ticketId: ticketId, message: message);
  }

  Future<LocalDashboardDataBundle?> _loadBundle() async {
    final preferences = await SharedPreferences.getInstance();
    final rawValue = preferences.getString(_bundleKey);
    if (rawValue == null || rawValue.trim().isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(rawValue);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      return LocalDashboardDataBundle.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveBundle(LocalDashboardDataBundle bundle) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_bundleKey, jsonEncode(bundle.toJson()));
  }

  LocalDashboardDataBundle _defaultBundle() {
    return LocalDashboardDataBundle(
      profile: UserProfile(
        id: 'local-profile',
        fullName: 'Utente',
        useUniformDailyTarget: true,
        dailyTargetMinutes: 480,
        weekdayTargetMinutes: const WeekdayTargetMinutes(
          monday: 480,
          tuesday: 480,
          wednesday: 480,
          thursday: 480,
          friday: 480,
          saturday: 0,
          sunday: 0,
        ),
        weekdaySchedule: const WeekdaySchedule(
          monday: DaySchedule(targetMinutes: 480, breakMinutes: 0),
          tuesday: DaySchedule(targetMinutes: 480, breakMinutes: 0),
          wednesday: DaySchedule(targetMinutes: 480, breakMinutes: 0),
          thursday: DaySchedule(targetMinutes: 480, breakMinutes: 0),
          friday: DaySchedule(targetMinutes: 480, breakMinutes: 0),
          saturday: DaySchedule(targetMinutes: 0, breakMinutes: 0),
          sunday: DaySchedule(targetMinutes: 0, breakMinutes: 0),
        ),
      ),
      workEntries: const [],
      leaveEntries: const [],
      scheduleOverrides: const [],
    );
  }

  DashboardSnapshot _buildSnapshot({
    required LocalDashboardDataBundle bundle,
    required String month,
  }) {
    final workEntries = bundle.workEntries
        .where((entry) => entry.date.startsWith(month))
        .toList(growable: false);
    final leaveEntries = bundle.leaveEntries
        .where((entry) => entry.date.startsWith(month))
        .toList(growable: false);
    final scheduleOverrides = bundle.scheduleOverrides
        .where((entry) => entry.date.startsWith(month))
        .toList(growable: false);

    final workedMinutes = workEntries.fold<int>(
      0,
      (sum, entry) => sum + entry.minutes,
    );
    final leaveMinutes = leaveEntries.fold<int>(
      0,
      (sum, entry) => sum + entry.minutes,
    );
    final expectedMinutes = _expectedMinutesForMonth(
      month,
      bundle.profile,
      scheduleOverrides,
    );

    return DashboardSnapshot(
      profile: bundle.profile,
      summary: MonthlySummary(
        month: month,
        expectedMinutes: expectedMinutes,
        workedMinutes: workedMinutes,
        leaveMinutes: leaveMinutes,
        balanceMinutes: workedMinutes + leaveMinutes - expectedMinutes,
      ),
      workEntries: workEntries.reversed.toList(growable: false),
      leaveEntries: leaveEntries.reversed.toList(growable: false),
      scheduleOverrides: scheduleOverrides.reversed.toList(growable: false),
      apiBaseUrl: _ticketApiClient?.baseUrl ?? 'local',
    );
  }

  int _expectedMinutesForMonth(
    String month,
    UserProfile profile,
    List<ScheduleOverride> overrides,
  ) {
    final parts = month.split('-');
    final year = int.parse(parts[0]);
    final monthNumber = int.parse(parts[1]);
    final daysInMonth = DateTime(year, monthNumber + 1, 0).day;
    final overridesByDate = {for (final entry in overrides) entry.date: entry};

    var total = 0;
    for (var day = 1; day <= daysInMonth; day += 1) {
      final date = DateTime(year, monthNumber, day);
      final isoDate = _formatDate(date);
      final override = overridesByDate[isoDate];
      total +=
          override?.targetMinutes ??
          profile.weekdaySchedule.forDate(date).targetMinutes;
    }

    return total;
  }

  String _formatDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}
