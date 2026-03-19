import 'package:work_hours_mobile/domain/models/dashboard_snapshot.dart';
import 'package:work_hours_mobile/domain/models/leave_entry.dart';
import 'package:work_hours_mobile/domain/models/weekday_target_minutes.dart';
import 'package:work_hours_mobile/domain/repositories/dashboard_repository.dart';

class DashboardService {
  DashboardService({required DashboardRepository repository})
    : _repository = repository;

  final DashboardRepository _repository;

  Future<DashboardSnapshot> loadSnapshot({String? month}) {
    return _repository.loadSnapshot(month: month ?? currentMonth);
  }

  Future<DashboardSnapshot> saveProfile({
    required String fullName,
    required bool useUniformDailyTarget,
    required int dailyTargetMinutes,
    required WeekdayTargetMinutes weekdayTargetMinutes,
    String? month,
  }) {
    return _repository.saveProfile(
      fullName: fullName,
      useUniformDailyTarget: useUniformDailyTarget,
      dailyTargetMinutes: dailyTargetMinutes,
      weekdayTargetMinutes: weekdayTargetMinutes,
      month: month ?? currentMonth,
    );
  }

  Future<DashboardSnapshot> addWorkEntry({
    required String date,
    required int minutes,
    String? note,
  }) {
    return _repository.addWorkEntry(
      date: date,
      minutes: minutes,
      note: note,
      month: date.substring(0, 7),
    );
  }

  Future<DashboardSnapshot> addLeaveEntry({
    required String date,
    required int minutes,
    required LeaveType type,
    String? note,
  }) {
    return _repository.addLeaveEntry(
      date: date,
      minutes: minutes,
      type: type,
      note: note,
      month: date.substring(0, 7),
    );
  }

  Future<DashboardSnapshot> saveScheduleOverride({
    required String date,
    required int targetMinutes,
    String? note,
  }) {
    return _repository.saveScheduleOverride(
      date: date,
      targetMinutes: targetMinutes,
      note: note,
      month: date.substring(0, 7),
    );
  }

  Future<DashboardSnapshot> removeScheduleOverride({
    required String date,
  }) {
    return _repository.removeScheduleOverride(
      date: date,
      month: date.substring(0, 7),
    );
  }

  String get currentMonth {
    return formatMonth(DateTime.now());
  }

  String get defaultEntryDate {
    return defaultEntryDateOf(DateTime.now());
  }

  static String formatMonth(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$year-$month';
  }

  static String defaultEntryDateOf(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}
