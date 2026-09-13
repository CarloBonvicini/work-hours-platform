// Bozza di orario del giorno: stato, validazione e descrizioni.

import 'package:work_hours_mobile/application/services/hour_input_parser.dart';
import 'package:work_hours_mobile/application/services/time_input_parser.dart';
import 'package:work_hours_mobile/domain/models/day_schedule.dart';
import 'package:work_hours_mobile/domain/models/weekday_schedule.dart';
import 'package:work_hours_mobile/domain/models/weekday_target_minutes.dart';
import 'package:work_hours_mobile/presentation/home/models/calendar_day.dart';

class ScheduleOverrideDraftState {
  const ScheduleOverrideDraftState({required this.schedule, this.pauseWindow});

  final DaySchedule schedule;
  final CalendarPauseWindow? pauseWindow;
}

String? validateScheduleDraft({
  required String targetText,
  required String startTimeText,
  required String endTimeText,
  required String breakText,
}) {
  final normalizedStart = startTimeText.trim();
  final normalizedEnd = endTimeText.trim();
  final hasStart = normalizedStart.isNotEmpty;
  final hasEnd = normalizedEnd.isNotEmpty;
  if (hasStart != hasEnd) {
    return 'Compila sia inizio che fine.';
  }

  final startMinutes = hasStart ? parseTimeInput(normalizedStart) : null;
  final endMinutes = hasEnd ? parseTimeInput(normalizedEnd) : null;
  if ((hasStart && startMinutes == null) || (hasEnd && endMinutes == null)) {
    return 'Controlla l orario inserito.';
  }

  final breakMinutes = parseBreakDurationInput(breakText);
  if (breakMinutes == null) {
    return 'Controlla la pausa.';
  }
  if ((!hasStart || !hasEnd) && breakMinutes > 0) {
    return 'La pausa richiede anche inizio e fine.';
  }

  final targetMinutes = resolveDraftTargetMinutes(
    targetText: targetText,
    startTimeText: startTimeText,
    endTimeText: endTimeText,
    breakText: breakText,
  );
  if (targetMinutes == null) {
    return 'Imposta inizio, fine e pausa della giornata.';
  }

  if (startMinutes != null && endMinutes != null) {
    final elapsedMinutes = endMinutes - startMinutes;
    if (elapsedMinutes < 0) {
      return 'L orario di fine deve essere dopo l inizio.';
    }
    if (breakMinutes > elapsedMinutes) {
      return 'La pausa non puo superare la durata della giornata.';
    }
  }

  return null;
}

int? resolveDraftTargetMinutes({
  required String targetText,
  required String startTimeText,
  required String endTimeText,
  required String breakText,
}) {
  final explicitTargetMinutes = parseHoursInput(targetText);
  if (explicitTargetMinutes != null) {
    return explicitTargetMinutes;
  }

  final startMinutes = parseTimeInput(startTimeText.trim());
  final endMinutes = parseTimeInput(endTimeText.trim());
  final breakMinutes = parseBreakDurationInput(breakText);
  if (startMinutes == null ||
      endMinutes == null ||
      breakMinutes == null ||
      endMinutes < startMinutes) {
    return null;
  }

  final elapsedMinutes = endMinutes - startMinutes;
  if (breakMinutes > elapsedMinutes) {
    return null;
  }

  return elapsedMinutes - breakMinutes;
}

/// Vero quando la bozza del giorno prevede ore di lavoro.
///
/// E' la definizione di "giorno lavorativo" usata sia dalle impostazioni sia
/// dal salvataggio dell'orario settimanale: deve restare una sola.
bool isWorkingDayDraft({
  required String targetText,
  required String startTimeText,
  required String endTimeText,
  required String breakText,
}) {
  final targetMinutes = resolveDraftTargetMinutes(
    targetText: targetText,
    startTimeText: startTimeText,
    endTimeText: endTimeText,
    breakText: breakText,
  );
  return (targetMinutes ?? 0) > 0;
}

/// Ore attese in una giornata lavorativa, mediate sui soli giorni con ore.
///
/// I giorni liberi non entrano nella media: contarli abbasserebbe le ore attese
/// di chi lavora meno giorni ma piu' a lungo.
int averageWorkingDayTargetMinutes(WeekdaySchedule schedule) {
  final workingTargets = [
    for (final weekday in WeekdayKey.values)
      schedule.forWeekday(weekday).targetMinutes,
  ].where((minutes) => minutes > 0).toList(growable: false);
  if (workingTargets.isEmpty) {
    return 0;
  }

  final total = workingTargets.reduce((value, next) => value + next);
  return (total / workingTargets.length).round();
}

String formatDayScheduleDetails(DaySchedule schedule) {
  final scheduleParts = <String>[];
  if (schedule.startTime != null && schedule.endTime != null) {
    scheduleParts.add('${schedule.startTime} - ${schedule.endTime}');
  }
  if (schedule.breakMinutes > 0) {
    scheduleParts.add('pausa ${formatHoursInput(schedule.breakMinutes)}');
  }
  if (scheduleParts.isEmpty) {
    return 'Orari da definire';
  }
  return scheduleParts.join(' - ');
}

String formatScheduleWindowDetails(DaySchedule schedule) {
  return formatDayScheduleDetails(schedule);
}

String compactWeekScheduleLabel(DaySchedule schedule) {
  if (schedule.startTime != null && schedule.endTime != null) {
    return '${schedule.startTime} - ${schedule.endTime}';
  }
  if (schedule.targetMinutes <= 0) {
    return 'Nessun turno';
  }
  return '${formatHoursInput(schedule.targetMinutes)} previste';
}
