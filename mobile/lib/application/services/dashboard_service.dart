import 'package:work_hours_mobile/domain/models/dashboard_snapshot.dart';
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
    required int dailyTargetMinutes,
    String? month,
  }) {
    return _repository.saveProfile(
      fullName: fullName,
      dailyTargetMinutes: dailyTargetMinutes,
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
