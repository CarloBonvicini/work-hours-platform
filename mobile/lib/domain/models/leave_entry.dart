enum LeaveType {
  vacation,
  permit,
  sickness;

  String get apiValue => name;

  String get label {
    switch (this) {
      case LeaveType.vacation:
        return 'Ferie';
      case LeaveType.permit:
        return 'Permesso';
      case LeaveType.sickness:
        return 'Malattia';
    }
  }

  static LeaveType fromJson(String value) {
    switch (value) {
      case 'vacation':
        return LeaveType.vacation;
      case 'permit':
        return LeaveType.permit;
      case 'sickness':
        return LeaveType.sickness;
    }

    // Tipi introdotti da versioni piu nuove dell'app non devono far fallire
    // il ripristino del backup: meglio un permesso generico che perdere dati.
    return LeaveType.permit;
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

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date,
      'minutes': minutes,
      'type': type.apiValue,
      if (note != null && note!.isNotEmpty) 'note': note,
    };
  }
}
