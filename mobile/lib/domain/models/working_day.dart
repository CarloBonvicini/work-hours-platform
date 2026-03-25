import 'dart:math' as math;

import 'package:work_hours_mobile/domain/models/user_work_rules.dart';

enum WorkingDayType {
  working,
  customSchedule,
  dayOff,
  vacation,
  permit;

  String get apiValue => name;

  static WorkingDayType fromJson(String value) {
    return WorkingDayType.values.firstWhere(
      (type) => type.apiValue == value,
      orElse: () => WorkingDayType.working,
    );
  }
}

class WorkingDay {
  const WorkingDay({
    required this.date,
    required this.dayType,
    required this.breakMinutes,
    required this.workedMinutes,
    required this.expectedMinutes,
    required this.balanceMinutes,
    this.startMinutes,
    this.endMinutes,
  });

  final String date;
  final WorkingDayType dayType;
  final int? startMinutes;
  final int? endMinutes;
  final int breakMinutes;
  final int workedMinutes;
  final int expectedMinutes;
  final int balanceMinutes;

  factory WorkingDay.fromTimeRange({
    required String date,
    required WorkingDayType dayType,
    int? startMinutes,
    int? endMinutes,
    int breakMinutes = 0,
    required int expectedMinutes,
  }) {
    final resolvedWorkedMinutes = startMinutes != null && endMinutes != null
        ? math.max(0, endMinutes - startMinutes - breakMinutes)
        : 0;

    return WorkingDay(
      date: date,
      dayType: dayType,
      startMinutes: startMinutes,
      endMinutes: endMinutes,
      breakMinutes: breakMinutes,
      workedMinutes: resolvedWorkedMinutes,
      expectedMinutes: expectedMinutes,
      balanceMinutes: resolvedWorkedMinutes - expectedMinutes,
    );
  }

  factory WorkingDay.fromWorkedMinutes({
    required String date,
    required WorkingDayType dayType,
    int? startMinutes,
    int? endMinutes,
    int breakMinutes = 0,
    required int workedMinutes,
    required int expectedMinutes,
  }) {
    return WorkingDay(
      date: date,
      dayType: dayType,
      startMinutes: startMinutes,
      endMinutes: endMinutes,
      breakMinutes: breakMinutes,
      workedMinutes: workedMinutes,
      expectedMinutes: expectedMinutes,
      balanceMinutes: workedMinutes - expectedMinutes,
    );
  }

  factory WorkingDay.fromJson(Map<String, dynamic> json) {
    return WorkingDay(
      date: json['date'] as String,
      dayType: WorkingDayType.fromJson(
        json['dayType'] as String? ?? WorkingDayType.working.apiValue,
      ),
      startMinutes: json['startMinutes'] as int?,
      endMinutes: json['endMinutes'] as int?,
      breakMinutes: json['breakMinutes'] as int? ?? 0,
      workedMinutes: json['workedMinutes'] as int,
      expectedMinutes: json['expectedMinutes'] as int,
      balanceMinutes: json['balanceMinutes'] as int,
    );
  }

  bool get hasRecordedRange => startMinutes != null && endMinutes != null;

  Map<String, dynamic> toJson() {
    return {
      'date': date,
      'dayType': dayType.apiValue,
      'breakMinutes': breakMinutes,
      'workedMinutes': workedMinutes,
      'expectedMinutes': expectedMinutes,
      'balanceMinutes': balanceMinutes,
      if (startMinutes != null) 'startMinutes': startMinutes,
      if (endMinutes != null) 'endMinutes': endMinutes,
    };
  }

  WorkingDay applyingRules(UserWorkRules rules) {
    return WorkingDay(
      date: date,
      dayType: dayType,
      startMinutes: startMinutes,
      endMinutes: endMinutes,
      breakMinutes: breakMinutes,
      workedMinutes: workedMinutes,
      expectedMinutes: expectedMinutes,
      balanceMinutes: rules.clampDailyBalance(balanceMinutes),
    );
  }
}
