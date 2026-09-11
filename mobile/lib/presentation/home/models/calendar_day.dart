// Modelli di vista di una cella/giorno del calendario.


class CalendarDay {
  const CalendarDay({
    required this.date,
    required this.isoDate,
    required this.expectedMinutes,
    required this.workedMinutes,
    required this.leaveMinutes,
    required this.hasOverride,
    required this.isToday,
    required this.isSelected,
    required this.relation,
    required this.primaryLabel,
    required this.secondaryLabel,
    required this.details,
  });

  const CalendarDay.empty()
    : date = null,
      isoDate = '',
      expectedMinutes = 0,
      workedMinutes = 0,
      leaveMinutes = 0,
      hasOverride = false,
      isToday = false,
      isSelected = false,
      relation = CalendarDayRelation.future,
      primaryLabel = null,
      secondaryLabel = null,
      details = null;

  final DateTime? date;
  final String isoDate;
  final int expectedMinutes;
  final int workedMinutes;
  final int leaveMinutes;
  final bool hasOverride;
  final bool isToday;
  final bool isSelected;
  final CalendarDayRelation relation;
  final String? primaryLabel;
  final String? secondaryLabel;
  final CalendarDayDetails? details;
}

enum CalendarDayRelation { past, today, future }

class CalendarDayDetails {
  const CalendarDayDetails({
    required this.timelineLines,
    required this.workedLabel,
    required this.pauseLabel,
    required this.workedMinutes,
    required this.pauseMinutes,
    this.startMinutes,
    this.pauseStartMinutes,
    this.resumeMinutes,
    this.endMinutes,
  });

  final List<String> timelineLines;
  final String workedLabel;
  final String pauseLabel;
  final int workedMinutes;
  final int pauseMinutes;
  final int? startMinutes;
  final int? pauseStartMinutes;
  final int? resumeMinutes;
  final int? endMinutes;
}

class CalendarPauseWindow {
  const CalendarPauseWindow({
    required this.pauseStartMinutes,
    required this.resumeMinutes,
  });

  final int pauseStartMinutes;
  final int resumeMinutes;
}
