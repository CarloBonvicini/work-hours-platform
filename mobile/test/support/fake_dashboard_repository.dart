// Doppio di test del repository dashboard, con profilo e dati di esempio.

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

class FakeDashboardRepository implements DashboardRepository {
  Map<String, ScheduleOverride> get savedScheduleOverrides =>
      Map.unmodifiable(_scheduleOverridesByDate);

  FakeDashboardRepository({
    Map<String, ScheduleOverride>? initialScheduleOverrides,
    List<WorkEntry>? initialWorkEntries,
    List<LeaveEntry>? initialLeaveEntries,
  }) : workEntries = [
         ...initialWorkEntries ??
             const [
               WorkEntry(
                 id: '1',
                 date: '2026-03-03',
                 minutes: 420,
                 note: 'Sprint mobile',
               ),
             ],
       ],
       leaveEntries = [
         ...initialLeaveEntries ??
             const [
               LeaveEntry(
                 id: 'leave-1',
                 date: '2026-03-04',
                 minutes: 60,
                 type: LeaveType.permit,
                 note: 'Visita medica',
               ),
             ],
       ],
       _scheduleOverridesByDate = {
         '2026-03-04': const ScheduleOverride(
           id: 'override-1',
           date: '2026-03-04',
           targetMinutes: 240,
           startTime: '09:00',
           endTime: '13:30',
           breakMinutes: 30,
           note: 'Scambio turno',
         ),
         ...?initialScheduleOverrides,
       };

  final Map<String, ScheduleOverride> _scheduleOverridesByDate;
  final List<WorkEntry> workEntries;
  final List<LeaveEntry> leaveEntries;
  final Map<String, SupportTicketThread> _ticketThreadsById = {};
  String? savedFullName;
  int? savedDailyTargetMinutes;
  WeekdayTargetMinutes? savedWeekdayTargetMinutes;
  WeekdaySchedule? savedWeekdaySchedule;
  UserWorkRules? savedWorkRules;
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
    leaveEntries.add(
      LeaveEntry(
        id: 'leave-${leaveEntries.length + 1}',
        date: date,
        minutes: minutes,
        type: type,
        note: note,
      ),
    );
    return loadSnapshot(month: month);
  }

  @override
  Future<DashboardSnapshot> addWorkEntry({
    required String date,
    required int minutes,
    String? note,
    required String month,
  }) {
    workEntries.add(
      WorkEntry(
        id: 'work-${workEntries.length + 1}',
        date: date,
        minutes: minutes,
        note: note,
      ),
    );
    return loadSnapshot(month: month);
  }

  @override
  Future<DashboardSnapshot> updateWorkEntry({
    required String id,
    required String date,
    required int minutes,
    String? note,
    required String month,
  }) {
    final index = workEntries.indexWhere((entry) => entry.id == id);
    workEntries[index] = WorkEntry(
      id: id,
      date: date,
      minutes: minutes,
      note: note,
    );
    return loadSnapshot(month: month);
  }

  @override
  Future<DashboardSnapshot> deleteWorkEntry({
    required String id,
    required String month,
  }) {
    workEntries.removeWhere((entry) => entry.id == id);
    return loadSnapshot(month: month);
  }

  @override
  Future<DashboardSnapshot> updateLeaveEntry({
    required String id,
    required String date,
    required int minutes,
    required LeaveType type,
    String? note,
    required String month,
  }) {
    final index = leaveEntries.indexWhere((entry) => entry.id == id);
    leaveEntries[index] = LeaveEntry(
      id: id,
      date: date,
      minutes: minutes,
      type: type,
      note: note,
    );
    return loadSnapshot(month: month);
  }

  @override
  Future<DashboardSnapshot> deleteLeaveEntry({
    required String id,
    required String month,
  }) {
    leaveEntries.removeWhere((entry) => entry.id == id);
    return loadSnapshot(month: month);
  }

  @override
  Future<DashboardSnapshot> loadSnapshot({required String month}) async {
    final weekdayTargetMinutes =
        savedWeekdayTargetMinutes ??
        WeekdayTargetMinutes(
          monday: 480,
          tuesday: 360,
          wednesday: 360,
          thursday: 480,
          friday: 480,
          saturday: 0,
          sunday: 0,
        );
    final weekdaySchedule =
        savedWeekdaySchedule ??
        WeekdaySchedule(
          monday: DaySchedule(
            targetMinutes: 480,
            startTime: '08:30',
            endTime: '17:00',
            breakMinutes: 30,
          ),
          tuesday: DaySchedule(
            targetMinutes: 360,
            startTime: '08:30',
            endTime: '15:00',
            breakMinutes: 30,
          ),
          wednesday: DaySchedule(
            targetMinutes: 360,
            startTime: '08:30',
            endTime: '15:00',
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
        );
    final workRules =
        savedWorkRules ??
        UserWorkRules.unbounded(
          expectedDailyMinutes: savedDailyTargetMinutes ?? 450,
          minimumBreakMinutes: 30,
        );
    return DashboardSnapshot(
      profile: UserProfile(
        id: 'default-profile',
        fullName: savedFullName ?? 'Carlo Bonvicini',
        useUniformDailyTarget: false,
        dailyTargetMinutes: savedDailyTargetMinutes ?? 450,
        weekdayTargetMinutes: weekdayTargetMinutes,
        weekdaySchedule: weekdaySchedule,
        workRules: workRules,
      ),
      summary: MonthlySummary.fromTotals(
        month: month,
        expectedMinutes: 10350,
        workedMinutes: 900,
        leaveMinutes: 60,
        rules: workRules,
      ),
      workEntries: List.unmodifiable(workEntries),
      leaveEntries: List.unmodifiable(leaveEntries),
      scheduleOverrides: _scheduleOverridesByDate.values.toList(
        growable: false,
      ),
      apiBaseUrl: 'http://localhost:8080/',
    );
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
  }) {
    savedFullName = fullName;
    savedDailyTargetMinutes = dailyTargetMinutes;
    savedWeekdayTargetMinutes = weekdayTargetMinutes;
    savedWeekdaySchedule = weekdaySchedule;
    savedWorkRules = workRules;
    return loadSnapshot(month: month);
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
  }) {
    _scheduleOverridesByDate[date] = ScheduleOverride(
      id: 'override-$date',
      date: date,
      targetMinutes: targetMinutes,
      startTime: startTime,
      endTime: endTime,
      breakMinutes: breakMinutes,
      note: note,
    );
    return loadSnapshot(month: month);
  }

  @override
  Future<DashboardSnapshot> removeScheduleOverride({
    required String date,
    required String month,
  }) {
    _scheduleOverridesByDate.remove(date);
    return loadSnapshot(month: month);
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
  }) async {
    submittedTicketCategory = category;
    submittedTicketName = name;
    submittedTicketEmail = email;
    submittedTicketSubject = subject;
    submittedTicketMessage = message;
    submittedTicketAppVersion = appVersion;
    final thread = SupportTicketThread(
      id: 'ticket-1',
      category: category,
      status: SupportTicketStatus.newTicket,
      subject: subject,
      message: message,
      createdAt: DateTime(2026, 3, 20, 9, 0),
      updatedAt: DateTime(2026, 3, 20, 9, 0),
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
    return thread;
  }

  @override
  Future<SupportTicketThread> fetchSupportTicket({
    required String ticketId,
  }) async {
    return _ticketThreadsById[ticketId] ??
        SupportTicketThread(
          id: 'ticket-1',
          category: SupportTicketCategory.support,
          status: SupportTicketStatus.newTicket,
          subject: 'Supporto',
          message: 'Messaggio',
          createdAt: DateTime(2026, 3, 20, 9),
          updatedAt: DateTime(2026, 3, 20, 9),
          attachments: const [],
          replies: [],
        );
  }

  @override
  Future<SupportTicketThread> replyToSupportTicket({
    required String ticketId,
    required String message,
  }) async {
    final currentThread = await fetchSupportTicket(ticketId: ticketId);
    final updatedThread = SupportTicketThread(
      id: currentThread.id,
      category: currentThread.category,
      status: SupportTicketStatus.inProgress,
      subject: currentThread.subject,
      message: currentThread.message,
      createdAt: currentThread.createdAt,
      updatedAt: DateTime(2026, 3, 20, 9, 30),
      attachments: currentThread.attachments,
      replies: [
        ...currentThread.replies,
        SupportTicketReply(
          id: 'reply-1',
          author: 'user',
          message: 'Grazie',
          createdAt: DateTime(2026, 3, 20, 9, 30),
        ),
      ],
      name: currentThread.name,
      email: currentThread.email,
      appVersion: currentThread.appVersion,
    );
    _ticketThreadsById[ticketId] = updatedThread;
    return updatedThread;
  }
}
