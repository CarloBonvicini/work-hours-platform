class ScheduleOverride {
  const ScheduleOverride({
    required this.id,
    required this.date,
    required this.targetMinutes,
    this.note,
  });

  final String id;
  final String date;
  final int targetMinutes;
  final String? note;

  factory ScheduleOverride.fromJson(Map<String, dynamic> json) {
    return ScheduleOverride(
      id: json['id'] as String,
      date: json['date'] as String,
      targetMinutes: json['targetMinutes'] as int,
      note: json['note'] as String?,
    );
  }
}
