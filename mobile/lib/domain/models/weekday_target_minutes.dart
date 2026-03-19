enum WeekdayKey {
  monday,
  tuesday,
  wednesday,
  thursday,
  friday,
  saturday,
  sunday;

  String get apiValue => name;

  String get label {
    switch (this) {
      case WeekdayKey.monday:
        return 'Lun';
      case WeekdayKey.tuesday:
        return 'Mar';
      case WeekdayKey.wednesday:
        return 'Mer';
      case WeekdayKey.thursday:
        return 'Gio';
      case WeekdayKey.friday:
        return 'Ven';
      case WeekdayKey.saturday:
        return 'Sab';
      case WeekdayKey.sunday:
        return 'Dom';
    }
  }
}

class WeekdayTargetMinutes {
  const WeekdayTargetMinutes({
    required this.monday,
    required this.tuesday,
    required this.wednesday,
    required this.thursday,
    required this.friday,
    required this.saturday,
    required this.sunday,
  });

  final int monday;
  final int tuesday;
  final int wednesday;
  final int thursday;
  final int friday;
  final int saturday;
  final int sunday;

  factory WeekdayTargetMinutes.uniform(int dailyTargetMinutes) {
    return WeekdayTargetMinutes(
      monday: dailyTargetMinutes,
      tuesday: dailyTargetMinutes,
      wednesday: dailyTargetMinutes,
      thursday: dailyTargetMinutes,
      friday: dailyTargetMinutes,
      saturday: 0,
      sunday: 0,
    );
  }

  factory WeekdayTargetMinutes.fromJson(Map<String, dynamic> json) {
    return WeekdayTargetMinutes(
      monday: json['monday'] as int,
      tuesday: json['tuesday'] as int,
      wednesday: json['wednesday'] as int,
      thursday: json['thursday'] as int,
      friday: json['friday'] as int,
      saturday: json['saturday'] as int,
      sunday: json['sunday'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'monday': monday,
      'tuesday': tuesday,
      'wednesday': wednesday,
      'thursday': thursday,
      'friday': friday,
      'saturday': saturday,
      'sunday': sunday,
    };
  }

  int forDate(DateTime date) {
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

  int forWeekday(WeekdayKey weekday) {
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
}
