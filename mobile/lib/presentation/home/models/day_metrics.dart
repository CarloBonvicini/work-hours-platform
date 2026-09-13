// Metriche aggregate di giorno, mese e settimana pianificata.

import 'package:work_hours_mobile/domain/models/day_schedule.dart';

class DayMetrics {
  const DayMetrics({
    required this.date,
    required this.expectedMinutes,
    required this.workedMinutes,
    required this.leaveMinutes,
    required this.rawBalanceMinutes,
    required this.balanceMinutes,
    required this.hasOverride,
    required this.schedule,
    this.overrideNote,
  });

  factory DayMetrics.empty(DateTime date) {
    return DayMetrics(
      date: date,
      expectedMinutes: 0,
      workedMinutes: 0,
      leaveMinutes: 0,
      rawBalanceMinutes: 0,
      balanceMinutes: 0,
      hasOverride: false,
      schedule: const DaySchedule(targetMinutes: 0),
    );
  }

  final DateTime date;
  final int expectedMinutes;
  final int workedMinutes;
  final int leaveMinutes;
  final int rawBalanceMinutes;
  final int balanceMinutes;
  final bool hasOverride;
  final DaySchedule schedule;
  final String? overrideNote;
}

class MonthMetrics {
  const MonthMetrics({
    required this.month,
    required this.expectedMinutes,
    required this.workedMinutes,
    required this.leaveMinutes,
    required this.rawBalanceMinutes,
    required this.balanceMinutes,
    required this.overrideCount,
  });

  factory MonthMetrics.empty(String month) {
    return MonthMetrics(
      month: month,
      expectedMinutes: 0,
      workedMinutes: 0,
      leaveMinutes: 0,
      rawBalanceMinutes: 0,
      balanceMinutes: 0,
      overrideCount: 0,
    );
  }

  final String month;
  final int expectedMinutes;
  final int workedMinutes;
  final int leaveMinutes;
  final int rawBalanceMinutes;
  final int balanceMinutes;
  final int overrideCount;
}
