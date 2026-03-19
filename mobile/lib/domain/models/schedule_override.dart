class ScheduleOverride {
  const ScheduleOverride({
    required this.id,
    required this.date,
    required this.targetMinutes,
    this.startTime,
    this.endTime,
    this.breakMinutes = 0,
    this.note,
  });

  final String id;
  final String date;
  final int targetMinutes;
  final String? startTime;
  final String? endTime;
  final int breakMinutes;
  final String? note;

  factory ScheduleOverride.fromJson(Map<String, dynamic> json) {
    return ScheduleOverride(
      id: json['id'] as String,
      date: json['date'] as String,
      targetMinutes: json['targetMinutes'] as int,
      startTime: json['startTime'] as String?,
      endTime: json['endTime'] as String?,
      breakMinutes: json['breakMinutes'] as int? ?? 0,
      note: json['note'] as String?,
    );
  }
}
