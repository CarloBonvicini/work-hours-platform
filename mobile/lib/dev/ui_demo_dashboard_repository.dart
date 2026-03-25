import 'package:work_hours_mobile/domain/models/dashboard_snapshot.dart';
import 'package:work_hours_mobile/domain/models/day_schedule.dart';
import 'package:work_hours_mobile/domain/models/leave_entry.dart';
import 'package:work_hours_mobile/domain/models/monthly_summary.dart';
import 'package:work_hours_mobile/domain/models/profile.dart';
import 'package:work_hours_mobile/domain/models/schedule_override.dart';
import 'package:work_hours_mobile/domain/models/support_ticket.dart';
import 'package:work_hours_mobile/domain/models/user_work_rules.dart';
import 'package:work_hours_mobile/domain/models/weekday_schedule.dart';
import 'package:work_hours_mobile/domain/models/weekday_target_minutes.dart';
import 'package:work_hours_mobile/domain/models/work_entry.dart';
import 'package:work_hours_mobile/domain/repositories/dashboard_repository.dart';

class UiDemoDashboardRepository implements DashboardRepository {
  UiDemoDashboardRepository() {
    final now = DateTime.now();
    final currentMonth = _formatMonth(now);
    final today = _formatDate(now);
    final yesterday = _formatDate(now.subtract(const Duration(days: 1)));
    final twoDaysAgo = _formatDate(now.subtract(const Duration(days: 2)));
    final upcomingLateDay = _formatDate(now.add(const Duration(days: 2)));

    _profile = UserProfile(
      id: 'ui-demo-profile',
      fullName: 'Carlo Bonvicini',
      useUniformDailyTarget: false,
      dailyTargetMinutes: 450,
      weekdayTargetMinutes: const WeekdayTargetMinutes(
        monday: 480,
        tuesday: 360,
        wednesday: 360,
        thursday: 480,
        friday: 480,
        saturday: 0,
        sunday: 0,
      ),
      weekdaySchedule: const WeekdaySchedule(
        monday: DaySchedule(
          targetMinutes: 480,
          startTime: '08:30',
          endTime: '17:00',
          breakMinutes: 30,
        ),
        tuesday: DaySchedule(
          targetMinutes: 360,
          startTime: '09:00',
          endTime: '15:30',
          breakMinutes: 30,
        ),
        wednesday: DaySchedule(
          targetMinutes: 360,
          startTime: '09:00',
          endTime: '15:30',
          breakMinutes: 30,
        ),
        thursday: DaySchedule(
          targetMinutes: 480,
          startTime: '08:30',
          endTime: '17:00',
          breakMinutes: 30,
        ),
        friday: DaySchedule(
          targetMinutes: 480,
          startTime: '08:30',
          endTime: '17:00',
          breakMinutes: 30,
        ),
        saturday: DaySchedule(targetMinutes: 0),
        sunday: DaySchedule(targetMinutes: 0),
      ),
      workRules: UserProfile.defaultWorkRules(
        dailyTargetMinutes: 450,
        weekdaySchedule: const WeekdaySchedule(
          monday: DaySchedule(
            targetMinutes: 480,
            startTime: '08:30',
            endTime: '17:00',
            breakMinutes: 30,
          ),
          tuesday: DaySchedule(
            targetMinutes: 360,
            startTime: '09:00',
            endTime: '15:30',
            breakMinutes: 30,
          ),
          wednesday: DaySchedule(
            targetMinutes: 360,
            startTime: '09:00',
            endTime: '15:30',
            breakMinutes: 30,
          ),
          thursday: DaySchedule(
            targetMinutes: 480,
            startTime: '08:30',
            endTime: '17:00',
            breakMinutes: 30,
          ),
          friday: DaySchedule(
            targetMinutes: 480,
            startTime: '08:30',
            endTime: '17:00',
            breakMinutes: 30,
          ),
          saturday: DaySchedule(targetMinutes: 0),
          sunday: DaySchedule(targetMinutes: 0),
        ),
      ),
    );

    _workEntriesByMonth[currentMonth] = [
      WorkEntry(
        id: 'work-1',
        date: twoDaysAgo,
        minutes: 420,
        note: 'Analisi UI calendario',
      ),
      WorkEntry(
        id: 'work-2',
        date: yesterday,
        minutes: 390,
        note: 'Revisione impostazioni',
      ),
      WorkEntry(
        id: 'work-3',
        date: today,
        minutes: 240,
        note: 'Lavoro in corso',
      ),
    ];

    _leaveEntriesByMonth[currentMonth] = [
      LeaveEntry(
        id: 'leave-1',
        date: today,
        minutes: 30,
        type: LeaveType.permit,
        note: 'Commissione breve',
      ),
    ];

    _scheduleOverridesByMonth[currentMonth] = [
      ScheduleOverride(
        id: 'override-1',
        date: upcomingLateDay,
        targetMinutes: 420,
        startTime: '10:00',
        endTime: '18:00',
        breakMinutes: 60,
        note: 'Entrata posticipata',
      ),
    ];
  }

  late UserProfile _profile;
  final Map<String, List<WorkEntry>> _workEntriesByMonth = {};
  final Map<String, List<LeaveEntry>> _leaveEntriesByMonth = {};
  final Map<String, List<ScheduleOverride>> _scheduleOverridesByMonth = {};
  final List<Map<String, Object?>> submittedTickets = [];
  final Map<String, SupportTicketThread> _ticketThreadsById = {};

  String _nextTicketId() {
    return 'ticket-${DateTime.now().microsecondsSinceEpoch}';
  }

  @override
  Future<DashboardSnapshot> loadSnapshot({required String month}) async {
    return _buildSnapshot(month);
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
    _profile = UserProfile(
      id: _profile.id,
      fullName: fullName,
      useUniformDailyTarget: useUniformDailyTarget,
      dailyTargetMinutes: dailyTargetMinutes,
      weekdayTargetMinutes: weekdayTargetMinutes,
      weekdaySchedule: weekdaySchedule,
      workRules: workRules,
    );
    return _buildSnapshot(month);
  }

  @override
  Future<DashboardSnapshot> addWorkEntry({
    required String date,
    required int minutes,
    String? note,
    required String month,
  }) async {
    final entries = _workEntriesByMonth.putIfAbsent(month, () => []);
    entries.add(
      WorkEntry(
        id: 'work-${DateTime.now().microsecondsSinceEpoch}',
        date: date,
        minutes: minutes,
        note: note,
      ),
    );
    return _buildSnapshot(month);
  }

  @override
  Future<DashboardSnapshot> addLeaveEntry({
    required String date,
    required int minutes,
    required LeaveType type,
    String? note,
    required String month,
  }) async {
    final entries = _leaveEntriesByMonth.putIfAbsent(month, () => []);
    entries.add(
      LeaveEntry(
        id: 'leave-${DateTime.now().microsecondsSinceEpoch}',
        date: date,
        minutes: minutes,
        type: type,
        note: note,
      ),
    );
    return _buildSnapshot(month);
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
    final overrides = _scheduleOverridesByMonth.putIfAbsent(month, () => []);
    overrides.removeWhere((entry) => entry.date == date);
    overrides.add(
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
    return _buildSnapshot(month);
  }

  @override
  Future<DashboardSnapshot> removeScheduleOverride({
    required String date,
    required String month,
  }) async {
    final overrides = _scheduleOverridesByMonth.putIfAbsent(month, () => []);
    overrides.removeWhere((entry) => entry.date == date);
    return _buildSnapshot(month);
  }

  @override
  Future<SupportTicketThread> submitSupportTicket({
    required SupportTicketCategory category,
    String? name,
    String? email,
    required String subject,
    required String message,
    String? appVersion,
    List<SupportTicketUploadAttachment> attachments = const [],
  }) async {
    final now = DateTime.now();
    final thread = SupportTicketThread(
      id: _nextTicketId(),
      category: category,
      status: SupportTicketStatus.newTicket,
      subject: subject,
      message: message,
      createdAt: now,
      updatedAt: now,
      attachments: attachments
          .asMap()
          .entries
          .map(
            (entry) => SupportTicketAttachment(
              id: 'attachment-${entry.key + 1}',
              fileName: entry.value.fileName,
              contentType: entry.value.contentType,
              sizeBytes: entry.value.sizeBytes,
            ),
          )
          .toList(growable: false),
      replies: const [],
      name: name,
      email: email,
      appVersion: appVersion,
    );
    _ticketThreadsById[thread.id] = thread;
    submittedTickets.add({
      'id': thread.id,
      'category': category.apiValue,
      'name': name,
      'email': email,
      'subject': subject,
      'message': message,
      'appVersion': appVersion,
      'attachmentCount': attachments.length,
    });
    return thread;
  }

  @override
  Future<SupportTicketThread> fetchSupportTicket({
    required String ticketId,
  }) async {
    final thread = _ticketThreadsById[ticketId];
    if (thread == null) {
      throw Exception('Ticket non trovato');
    }
    return thread;
  }

  @override
  Future<SupportTicketThread> replyToSupportTicket({
    required String ticketId,
    required String message,
  }) async {
    final thread = _ticketThreadsById[ticketId];
    if (thread == null) {
      throw Exception('Ticket non trovato');
    }

    final updatedThread = SupportTicketThread(
      id: thread.id,
      category: thread.category,
      status: SupportTicketStatus.inProgress,
      subject: thread.subject,
      message: thread.message,
      createdAt: thread.createdAt,
      updatedAt: DateTime.now(),
      attachments: thread.attachments,
      replies: [
        ...thread.replies,
        SupportTicketReply(
          id: _nextTicketId(),
          author: 'user',
          message: message,
          createdAt: DateTime.now(),
        ),
      ],
      name: thread.name,
      email: thread.email,
      appVersion: thread.appVersion,
    );
    _ticketThreadsById[ticketId] = updatedThread;
    return updatedThread;
  }

  DashboardSnapshot _buildSnapshot(String month) {
    final workEntries = List<WorkEntry>.from(_workEntriesByMonth[month] ?? []);
    final leaveEntries = List<LeaveEntry>.from(
      _leaveEntriesByMonth[month] ?? [],
    );
    final overrides = List<ScheduleOverride>.from(
      _scheduleOverridesByMonth[month] ?? [],
    );

    final expectedMinutes = _expectedMinutesForMonth(month, overrides);
    final workedMinutes = workEntries.fold<int>(
      0,
      (sum, entry) => sum + entry.minutes,
    );
    final leaveMinutes = leaveEntries.fold<int>(
      0,
      (sum, entry) => sum + entry.minutes,
    );

    return DashboardSnapshot(
      profile: _profile,
      summary: MonthlySummary.fromTotals(
        month: month,
        expectedMinutes: expectedMinutes,
        workedMinutes: workedMinutes,
        leaveMinutes: leaveMinutes,
        rules: _profile.workRules,
      ),
      workEntries: workEntries..sort((a, b) => b.date.compareTo(a.date)),
      leaveEntries: leaveEntries..sort((a, b) => b.date.compareTo(a.date)),
      scheduleOverrides: overrides..sort((a, b) => a.date.compareTo(b.date)),
      apiBaseUrl: 'ui-demo',
    );
  }

  int _expectedMinutesForMonth(String month, List<ScheduleOverride> overrides) {
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
          _profile.weekdaySchedule.forDate(date).targetMinutes;
    }

    return total;
  }
}

String _formatMonth(DateTime date) {
  final year = date.year.toString().padLeft(4, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$year-$month';
}

String _formatDate(DateTime date) {
  final year = date.year.toString().padLeft(4, '0');
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}
