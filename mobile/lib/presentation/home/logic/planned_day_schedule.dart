// Orario previsto del giorno: completa entrata e uscita quando il piano
// settimanale indica solo le ore, cosi' la modifica rapida parte sempre dai
// valori previsti invece che da --:--.

import 'package:work_hours_mobile/application/services/time_input_parser.dart';
import 'package:work_hours_mobile/domain/models/day_schedule.dart';
import 'package:work_hours_mobile/domain/models/weekday_schedule.dart';
import 'package:work_hours_mobile/domain/models/weekday_target_minutes.dart';
import 'package:work_hours_mobile/presentation/home/logic/expected_exit.dart';

/// Entrata proposta quando nessun giorno della settimana ne definisce una.
const int fallbackPlannedStartMinutes = 9 * 60;

/// Entrata di riferimento: il primo giorno della settimana che ne dichiara una.
int resolvePlannedStartMinutes(WeekdaySchedule weekdaySchedule) {
  for (final weekday in WeekdayKey.values) {
    final startMinutes = parseTimeInput(
      weekdaySchedule.forWeekday(weekday).startTime,
    );
    if (startMinutes != null) {
      return startMinutes;
    }
  }

  return fallbackPlannedStartMinutes;
}

/// Orario previsto completo del giorno.
///
/// Le ore restano quelle del piano: vengono solo derivati entrata e uscita
/// mancanti, cosi' i saldi non cambiano. Le giornate libere (zero ore) non
/// vengono toccate.
DaySchedule completePlannedDaySchedule(
  DaySchedule schedule, {
  required int referenceStartMinutes,
}) {
  if (schedule.targetMinutes <= 0) {
    return schedule;
  }

  final declaredStartMinutes = parseTimeInput(schedule.startTime);
  final declaredEndMinutes = parseTimeInput(schedule.endTime);
  if (declaredStartMinutes != null && declaredEndMinutes != null) {
    return schedule;
  }

  final startMinutes =
      declaredStartMinutes ??
      (declaredEndMinutes == null
          ? referenceStartMinutes
          : resolveExpectedStartMinutes(
              endMinutes: declaredEndMinutes,
              targetMinutes: schedule.targetMinutes,
              breakMinutes: schedule.breakMinutes,
            ));
  final endMinutes =
      declaredEndMinutes ??
      clampExitToDayEnd(
        resolveExpectedExitMinutes(
          startMinutes: startMinutes,
          targetMinutes: schedule.targetMinutes,
          breakMinutes: schedule.breakMinutes,
        ),
      );
  if (endMinutes <= startMinutes) {
    return schedule;
  }

  return DaySchedule(
    targetMinutes: schedule.targetMinutes,
    startTime: formatTimeInput(startMinutes),
    endTime: formatTimeInput(endMinutes),
    breakMinutes: schedule.breakMinutes,
  );
}
