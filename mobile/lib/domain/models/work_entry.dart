class WorkEntry {
  const WorkEntry({
    required this.id,
    required this.date,
    required this.minutes,
    this.note,
  });

  final String id;
  final String date;
  final int minutes;
  final String? note;

  factory WorkEntry.fromJson(Map<String, dynamic> json) {
    return WorkEntry(
      id: json['id'] as String,
      date: json['date'] as String,
      minutes: json['minutes'] as int,
      note: json['note'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date,
      'minutes': minutes,
      if (note != null && note!.isNotEmpty) 'note': note,
    };
  }
}
