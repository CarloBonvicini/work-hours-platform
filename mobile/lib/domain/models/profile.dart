import 'package:work_hours_mobile/domain/models/weekday_schedule.dart';
import 'package:work_hours_mobile/domain/models/weekday_target_minutes.dart';
import 'package:work_hours_mobile/domain/models/user_work_rules.dart';

class UserProfile {
  const UserProfile({
    required this.id,
    required this.fullName,
    required this.useUniformDailyTarget,
    required this.dailyTargetMinutes,
    required this.weekdayTargetMinutes,
    required this.weekdaySchedule,
    required this.workRules,
  });

  final String id;
  final String fullName;
  final bool useUniformDailyTarget;
  final int dailyTargetMinutes;
  final WeekdayTargetMinutes weekdayTargetMinutes;
  final WeekdaySchedule weekdaySchedule;
  final UserWorkRules workRules;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final weekdayTargets = WeekdayTargetMinutes.fromJson(
      json['weekdayTargetMinutes'] as Map<String, dynamic>,
    );
    final weekdaySchedule = WeekdaySchedule.fromJson(
      json['weekdaySchedule'] as Map<String, dynamic>? ?? const {},
      fallbackTargets: weekdayTargets,
    );
    final dailyTargetMinutes = json['dailyTargetMinutes'] as int;
    return UserProfile(
      id: json['id'] as String,
      fullName: json['fullName'] as String,
      useUniformDailyTarget: json['useUniformDailyTarget'] as bool? ?? true,
      dailyTargetMinutes: dailyTargetMinutes,
      weekdayTargetMinutes: weekdayTargets,
      weekdaySchedule: weekdaySchedule,
      workRules: UserWorkRules.fromJson(
        json['workRules'] as Map<String, dynamic>? ?? const {},
        fallbackExpectedDailyMinutes: dailyTargetMinutes,
        fallbackMinimumBreakMinutes: defaultMinimumBreakMinutes(
          weekdaySchedule,
        ),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fullName': fullName,
      'useUniformDailyTarget': useUniformDailyTarget,
      'dailyTargetMinutes': dailyTargetMinutes,
      'weekdayTargetMinutes': weekdayTargetMinutes.toJson(),
      'weekdaySchedule': weekdaySchedule.toJson(),
      'workRules': workRules.toJson(),
    };
  }

  static int defaultMinimumBreakMinutes(WeekdaySchedule weekdaySchedule) {
    final scheduledBreaks = <int>[
      weekdaySchedule.monday.breakMinutes,
      weekdaySchedule.tuesday.breakMinutes,
      weekdaySchedule.wednesday.breakMinutes,
      weekdaySchedule.thursday.breakMinutes,
      weekdaySchedule.friday.breakMinutes,
      weekdaySchedule.saturday.breakMinutes,
      weekdaySchedule.sunday.breakMinutes,
    ].where((minutes) => minutes > 0);

    if (scheduledBreaks.isEmpty) {
      return 0;
    }

    return scheduledBreaks.reduce(
      (current, next) => current < next ? current : next,
    );
  }

  static UserWorkRules defaultWorkRules({
    required int dailyTargetMinutes,
    required WeekdaySchedule weekdaySchedule,
  }) {
    return UserWorkRules.unbounded(
      expectedDailyMinutes: dailyTargetMinutes,
      minimumBreakMinutes: defaultMinimumBreakMinutes(weekdaySchedule),
    );
  }
}
