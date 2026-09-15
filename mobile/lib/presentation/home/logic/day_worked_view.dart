// Cosa la vista giorno considera "lavorato", e perche'.

import 'package:work_hours_mobile/application/services/time_input_parser.dart';
import 'package:work_hours_mobile/application/services/workday_start_store.dart';
import 'package:work_hours_mobile/domain/models/day_schedule.dart';
import 'package:work_hours_mobile/domain/models/user_work_rules.dart';
import 'package:work_hours_mobile/presentation/home/logic/day_balance.dart';
import 'package:work_hours_mobile/presentation/home/logic/unrecorded_worked_minutes.dart';
import 'package:work_hours_mobile/presentation/home/models/calendar_day.dart';
import 'package:work_hours_mobile/presentation/home/models/day_metrics.dart';

/// Le ore della giornata selezionata e da dove arrivano.
class DayWorkedView {
  const DayWorkedView({
    required this.workedMinutes,
    required this.hasResultContext,
    required this.isDayOff,
    required this.hasWorkedOverride,
    required this.hasExitSuggestionContext,
    required this.unrecordedMinutes,
    required this.hasElapsedManualExit,
  });

  /// Ore da mostrare: zero finche' non c'e' niente di registrato.
  final int workedMinutes;

  /// La giornata ha qualcosa di reale da raccontare, non solo un piano.
  final bool hasResultContext;

  /// Giornata dichiarata libera nella modifica rapida.
  final bool isDayOff;

  /// Gli orari del giorno non sono quelli standard.
  final bool hasWorkedOverride;

  /// C'e' abbastanza per proporre un'uscita.
  final bool hasExitSuggestionContext;

  /// Ore che l'orario del giorno implica ma che nessuno ha registrato.
  final int? unrecordedMinutes;

  /// L'uscita scritta a mano per oggi e' gia' passata.
  final bool hasElapsedManualExit;
}

/// Mette insieme, in un posto solo, cosa vale come ora lavorata.
///
/// Prima queste condizioni nascevano sparse dentro il `build`, una variabile
/// per caso: e' il motivo per cui una giornata con entrata e uscita a video
/// poteva mostrare "Lavorate 0:00" senza spiegare niente.
DayWorkedView resolveDayWorkedView({
  required DaySchedule quickEditorSchedule,
  required DaySchedule baseSchedule,
  required UserWorkRules workRules,
  required DayMetrics dayMetrics,
  required WorkdaySession? session,
  required CalendarPauseWindow? pauseWindow,
  required String rawStartTimeText,
  required String rawEndTimeText,
  required bool isToday,
  required int nowMinutes,
}) {
  final isDayOff = isExplicitDayOffSchedule(quickEditorSchedule);
  final hasTimeWindow =
      (quickEditorSchedule.startTime?.trim().isNotEmpty ?? false) ||
      (quickEditorSchedule.endTime?.trim().isNotEmpty ?? false);
  final hasWorkedOverride =
      hasTimeWindow &&
      (quickEditorSchedule.startTime != baseSchedule.startTime ||
          quickEditorSchedule.endTime != baseSchedule.endTime);

  final endMinutesForToday =
      parseTimeInput(rawEndTimeText.trim()) ??
      parseTimeInput(quickEditorSchedule.endTime);
  final hasElapsedManualExit =
      !isDayOff &&
      isToday &&
      hasWorkedOverride &&
      endMinutesForToday != null &&
      endMinutesForToday <= nowMinutes;

  final hasResultContext =
      (isToday && session != null) ||
      dayMetrics.workedMinutes > 0 ||
      dayMetrics.leaveMinutes > 0 ||
      hasElapsedManualExit ||
      (isToday &&
          (rawStartTimeText.trim().isNotEmpty ||
              rawEndTimeText.trim().isNotEmpty));

  final workedMinutes = isToday
      ? resolveLiveWorkedMinutes(
          quickEditorSchedule: quickEditorSchedule,
          workRules: workRules,
          session: session,
          pauseWindow: pauseWindow,
          nowMinutes: nowMinutes,
          rawStartTimeText: rawStartTimeText,
          rawEndTimeText: rawEndTimeText,
          treatEndAsActual: hasElapsedManualExit,
        )
      // Un altro giorno ha solo le ore registrate: gli orari del piano, o di un
      // giorno futuro, non sono ore fatte.
      : dayMetrics.workedMinutes;

  final startMinutesForSuggestion =
      parseTimeInput(rawStartTimeText.trim()) ??
      parseTimeInput(quickEditorSchedule.startTime);

  return DayWorkedView(
    workedMinutes: hasResultContext ? workedMinutes : 0,
    hasResultContext: hasResultContext,
    isDayOff: isDayOff,
    hasWorkedOverride: hasWorkedOverride,
    hasExitSuggestionContext:
        hasResultContext || (!isDayOff && startMinutesForSuggestion != null),
    hasElapsedManualExit: hasElapsedManualExit,
    unrecordedMinutes: resolveUnrecordedWorkedMinutes(
      isToday: isToday,
      isDayOff: isDayOff,
      recordedWorkedMinutes: dayMetrics.workedMinutes,
      schedule: quickEditorSchedule,
      minimumBreakMinutes: workRules.minimumBreakMinutes,
    ),
  );
}
