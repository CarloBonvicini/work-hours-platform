import 'package:work_hours_mobile/domain/models/weekday_target_minutes.dart';

class UserProfile {
  const UserProfile({
    required this.id,
    required this.fullName,
    required this.useUniformDailyTarget,
    required this.dailyTargetMinutes,
    required this.weekdayTargetMinutes,
  });

  final String id;
  final String fullName;
  final bool useUniformDailyTarget;
  final int dailyTargetMinutes;
  final WeekdayTargetMinutes weekdayTargetMinutes;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      fullName: json['fullName'] as String,
      useUniformDailyTarget: json['useUniformDailyTarget'] as bool? ?? true,
      dailyTargetMinutes: json['dailyTargetMinutes'] as int,
      weekdayTargetMinutes: WeekdayTargetMinutes.fromJson(
        json['weekdayTargetMinutes'] as Map<String, dynamic>,
      ),
    );
  }
}
