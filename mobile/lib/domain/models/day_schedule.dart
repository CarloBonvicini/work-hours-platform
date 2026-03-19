class DaySchedule {
  const DaySchedule({
    required this.targetMinutes,
    this.startTime,
    this.endTime,
    this.breakMinutes = 0,
  });

  final int targetMinutes;
  final String? startTime;
  final String? endTime;
  final int breakMinutes;

  factory DaySchedule.fromJson(
    Map<String, dynamic> json, {
    required int fallbackTargetMinutes,
  }) {
    return DaySchedule(
      targetMinutes: json['targetMinutes'] as int? ?? fallbackTargetMinutes,
      startTime: json['startTime'] as String?,
      endTime: json['endTime'] as String?,
      breakMinutes: json['breakMinutes'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'targetMinutes': targetMinutes,
      'breakMinutes': breakMinutes,
      if (startTime != null && startTime!.isNotEmpty) 'startTime': startTime,
      if (endTime != null && endTime!.isNotEmpty) 'endTime': endTime,
    };
  }
}
