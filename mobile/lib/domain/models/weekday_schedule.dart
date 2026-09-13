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

  /// Giorni lavorativi predefiniti quando l'orario e' unico per tutti.
  static const defaultUniformWorkingDays = <WeekdayKey>{
    WeekdayKey.monday,
    WeekdayKey.tuesday,
    WeekdayKey.wednesday,
    WeekdayKey.thursday,
    WeekdayKey.friday,
  };

  /// Stesso orario su tutti i giorni lavorativi indicati, zero sugli altri.
  factory WeekdaySchedule.uniform(
    int dailyTargetMinutes, {
    String? startTime,
    String? endTime,
    int breakMinutes = 0,
    Set<WeekdayKey> workingDays = defaultUniformWorkingDays,
  }) {
    DaySchedule scheduleFor(WeekdayKey weekday) {
      if (!workingDays.contains(weekday)) {
        return const DaySchedule(targetMinutes: 0);
      }

      return DaySchedule(
        targetMinutes: dailyTargetMinutes,
        startTime: startTime,
        endTime: endTime,
        breakMinutes: breakMinutes,
      );
    }

    return WeekdaySchedule(
      monday: scheduleFor(WeekdayKey.monday),
      tuesday: scheduleFor(WeekdayKey.tuesday),
      wednesday: scheduleFor(WeekdayKey.wednesday),
      thursday: scheduleFor(WeekdayKey.thursday),
      friday: scheduleFor(WeekdayKey.friday),
      saturday: scheduleFor(WeekdayKey.saturday),
      sunday: scheduleFor(WeekdayKey.sunday),
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
