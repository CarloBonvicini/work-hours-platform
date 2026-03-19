import 'package:work_hours_mobile/domain/models/day_schedule.dart';
import 'package:work_hours_mobile/domain/models/weekday_target_minutes.dart';

class WeekdaySchedule {
  const WeekdaySchedule({
    required this.monday,
    required this.tuesday,
    required this.wednesday,
    required this.thursday,
    required this.friday,
    required this.saturday,
    required this.sunday,
  });

  final DaySchedule monday;
  final DaySchedule tuesday;
  final DaySchedule wednesday;
  final DaySchedule thursday;
  final DaySchedule friday;
  final DaySchedule saturday;
  final DaySchedule sunday;

  factory WeekdaySchedule.uniform(
    int dailyTargetMinutes, {
    String? startTime,
    String? endTime,
    int breakMinutes = 0,
  }) {
    return WeekdaySchedule(
      monday: DaySchedule(
        targetMinutes: dailyTargetMinutes,
        startTime: startTime,
        endTime: endTime,
        breakMinutes: breakMinutes,
      ),
      tuesday: DaySchedule(
        targetMinutes: dailyTargetMinutes,
        startTime: startTime,
        endTime: endTime,
        breakMinutes: breakMinutes,
      ),
      wednesday: DaySchedule(
        targetMinutes: dailyTargetMinutes,
        startTime: startTime,
        endTime: endTime,
        breakMinutes: breakMinutes,
      ),
      thursday: DaySchedule(
        targetMinutes: dailyTargetMinutes,
        startTime: startTime,
        endTime: endTime,
        breakMinutes: breakMinutes,
      ),
      friday: DaySchedule(
        targetMinutes: dailyTargetMinutes,
        startTime: startTime,
        endTime: endTime,
        breakMinutes: breakMinutes,
      ),
      saturday: const DaySchedule(targetMinutes: 0),
      sunday: const DaySchedule(targetMinutes: 0),
    );
  }

  factory WeekdaySchedule.fromJson(
    Map<String, dynamic> json, {
    required WeekdayTargetMinutes fallbackTargets,
  }) {
    return WeekdaySchedule(
      monday: DaySchedule.fromJson(
        json['monday'] as Map<String, dynamic>? ?? const {},
        fallbackTargetMinutes: fallbackTargets.monday,
      ),
      tuesday: DaySchedule.fromJson(
        json['tuesday'] as Map<String, dynamic>? ?? const {},
        fallbackTargetMinutes: fallbackTargets.tuesday,
      ),
      wednesday: DaySchedule.fromJson(
        json['wednesday'] as Map<String, dynamic>? ?? const {},
        fallbackTargetMinutes: fallbackTargets.wednesday,
      ),
      thursday: DaySchedule.fromJson(
        json['thursday'] as Map<String, dynamic>? ?? const {},
        fallbackTargetMinutes: fallbackTargets.thursday,
      ),
      friday: DaySchedule.fromJson(
        json['friday'] as Map<String, dynamic>? ?? const {},
        fallbackTargetMinutes: fallbackTargets.friday,
      ),
      saturday: DaySchedule.fromJson(
        json['saturday'] as Map<String, dynamic>? ?? const {},
        fallbackTargetMinutes: fallbackTargets.saturday,
      ),
      sunday: DaySchedule.fromJson(
        json['sunday'] as Map<String, dynamic>? ?? const {},
        fallbackTargetMinutes: fallbackTargets.sunday,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'monday': monday.toJson(),
      'tuesday': tuesday.toJson(),
      'wednesday': wednesday.toJson(),
      'thursday': thursday.toJson(),
      'friday': friday.toJson(),
      'saturday': saturday.toJson(),
      'sunday': sunday.toJson(),
    };
  }

  DaySchedule forWeekday(WeekdayKey weekday) {
    switch (weekday) {
      case WeekdayKey.monday:
        return monday;
      case WeekdayKey.tuesday:
        return tuesday;
      case WeekdayKey.wednesday:
        return wednesday;
      case WeekdayKey.thursday:
        return thursday;
      case WeekdayKey.friday:
        return friday;
      case WeekdayKey.saturday:
        return saturday;
      case WeekdayKey.sunday:
        return sunday;
    }
  }

  DaySchedule forDate(DateTime date) {
    switch (date.weekday) {
      case DateTime.monday:
        return monday;
      case DateTime.tuesday:
        return tuesday;
      case DateTime.wednesday:
        return wednesday;
      case DateTime.thursday:
        return thursday;
      case DateTime.friday:
        return friday;
      case DateTime.saturday:
        return saturday;
      default:
        return sunday;
    }
  }
}
