enum LeaveType {
  vacation,
  permit;

  String get apiValue => name;

  String get label {
    switch (this) {
      case LeaveType.vacation:
        return 'Ferie';
      case LeaveType.permit:
        return 'Permesso';
    }
  }

  static LeaveType fromJson(String value) {
    switch (value) {
      case 'vacation':
        return LeaveType.vacation;
      case 'permit':
        return LeaveType.permit;
    }

    throw ArgumentError.value(value, 'value', 'Unsupported leave type');
  }
}

class LeaveEntry {
  const LeaveEntry({
    required this.id,
    required this.date,
    required this.minutes,
    required this.type,
    this.note,
  });

  final String id;
  final String date;
  final int minutes;
  final LeaveType type;
  final String? note;

  factory LeaveEntry.fromJson(Map<String, dynamic> json) {
    return LeaveEntry(
      id: json['id'] as String,
      date: json['date'] as String,
      minutes: json['minutes'] as int,
      type: LeaveType.fromJson(json['type'] as String),
      note: json['note'] as String?,
    );
  }
}
