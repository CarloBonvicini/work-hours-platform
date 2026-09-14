// Uscita prevista: l'unico posto dove si calcola quando si puo' uscire.

import 'dart:math' as math;
import 'package:work_hours_mobile/application/services/time_input_parser.dart';
import 'package:work_hours_mobile/domain/models/day_schedule.dart';

const int _lastMinuteOfDay = (23 * 60) + 59;

/// Quando si puo' uscire: entrata + ore da fare + pausa.
///
/// La regola sta scritta qui e basta. Prima viveva in sei punti diversi con tre
/// regole diverse sulla pausa: la stessa giornata poteva mostrare uscite
/// previste che non erano d'accordo fra loro.
int resolveExpectedExitMinutes({
  required int startMinutes,
  required int targetMinutes,
  required int breakMinutes,
}) {
  return startMinutes +
      math.max<int>(0, targetMinutes) +
      math.max<int>(0, breakMinutes);
}

/// L'entrata che porta a una certa uscita: il conto letto al contrario.
///
/// Serve quando il piano dichiara solo l'uscita e le ore.
int resolveExpectedStartMinutes({
  required int endMinutes,
  required int targetMinutes,
  required int breakMinutes,
}) {
  return math.max<int>(
    0,
    endMinutes - math.max<int>(0, targetMinutes) - math.max<int>(0, breakMinutes),
  );
}

/// La pausa che sposta l'uscita.
///
/// Vince la piu' lunga fra quella gia' fatta, quella prevista e il minimo
/// imposto dalle regole: chi si ferma di piu' esce piu' tardi.
int resolveExpectedExitBreakMinutes({
  required int plannedBreakMinutes,
  int actualBreakMinutes = 0,
  int minimumBreakMinutes = 0,
}) {
  return math.max<int>(
    math.max<int>(0, plannedBreakMinutes),
    math.max<int>(actualBreakMinutes, minimumBreakMinutes),
  );
}

/// Uscita riportata dentro la giornata, per i campi che tengono un orario.
int clampExitToDayEnd(int exitMinutes) {
  return exitMinutes.clamp(0, _lastMinuteOfDay);
}

/// Orario dell'uscita, con il giorno dopo segnalato da [nextDaySuffix].
String formatExpectedExitLabel(
  int exitMinutes, {
  String nextDaySuffix = ' +1g',
}) {
  final normalizedMinutes = exitMinutes % (24 * 60);
  final suffix = exitMinutes >= (24 * 60) ? nextDaySuffix : '';
  return '${formatTimeInput(normalizedMinutes)}$suffix';
}

/// Uscita prevista di un orario del giorno, pausa fatta inclusa.
///
/// La scorciatoia per chi ha gia' in mano un [DaySchedule]: evita di rimettere
/// in fila ore e pausa a ogni chiamata.
int resolveScheduleExitMinutes(
  DaySchedule schedule, {
  required int startMinutes,
  int actualBreakMinutes = 0,
  int minimumBreakMinutes = 0,
}) {
  return resolveExpectedExitMinutes(
    startMinutes: startMinutes,
    targetMinutes: schedule.targetMinutes,
    breakMinutes: resolveExpectedExitBreakMinutes(
      plannedBreakMinutes: schedule.breakMinutes,
      actualBreakMinutes: actualBreakMinutes,
      minimumBreakMinutes: minimumBreakMinutes,
    ),
  );
}
