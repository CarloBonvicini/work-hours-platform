import 'package:work_hours_mobile/domain/models/dashboard_snapshot.dart';
import 'package:work_hours_mobile/domain/models/leave_entry.dart';

abstract class DashboardRepository {
  Future<DashboardSnapshot> loadSnapshot({required String month});

  Future<DashboardSnapshot> saveProfile({
    required String fullName,
    required int dailyTargetMinutes,
    required String month,
  });

  Future<DashboardSnapshot> addWorkEntry({
    required String date,
    required int minutes,
    String? note,
    required String month,
  });

  Future<DashboardSnapshot> addLeaveEntry({
    required String date,
    required int minutes,
    required LeaveType type,
    String? note,
    required String month,
  });
}
