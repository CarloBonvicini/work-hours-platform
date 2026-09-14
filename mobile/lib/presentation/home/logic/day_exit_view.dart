// Tutto quello che la vista giorno deve sapere sull'uscita, in un posto solo.

import 'package:work_hours_mobile/application/services/time_input_parser.dart';
import 'package:work_hours_mobile/application/services/workday_start_store.dart';
import 'package:work_hours_mobile/domain/models/day_schedule.dart';
import 'package:work_hours_mobile/domain/models/user_work_rules.dart';
import 'package:work_hours_mobile/presentation/home/logic/day_balance.dart';
import 'package:work_hours_mobile/presentation/home/logic/expected_exit.dart';
import 'package:work_hours_mobile/presentation/home/logic/quick_day_summary_label.dart';
import 'package:work_hours_mobile/presentation/home/logic/workday_session_info.dart';

/// Come si presenta l'uscita della giornata selezionata.
class DayExitView {
  const DayExitView({
    required this.suggestedLabel,
    required this.suggestedTotalMinutes,
    required this.hasScheduledExit,
    required this.remainingMinutes,
    required this.remainingLabel,
    required this.hasPendingConfirmation,
    required this.isForecast,
    required this.confirmableMinutes,
  });

  /// Orario da mostrare quando l'uscita e' ancora una previsione.
  final String suggestedLabel;

  /// La stessa previsione in minuti, oltre la mezzanotte compresa.
  final int? suggestedTotalMinutes;

  /// C'e' gia' un orario di uscita nel giorno.
  final bool hasScheduledExit;

  /// Minuti di orologio che mancano all'uscita, solo per oggi.
  final int? remainingMinutes;

  /// Lo stesso in parole ("Mancano 4:26 all'uscita prevista").
  final String? remainingLabel;

  /// L'uscita calcolata aspetta un "Conferma".
  final bool hasPendingConfirmation;

  /// L'uscita mostrata e' una previsione, non un orario registrato.
  final bool isForecast;

  /// Uscita confermabile con un tocco, se sta dentro la giornata.
  final int? confirmableMinutes;
}

/// Raccoglie in un colpo solo previsione, attesa e conferma dell'uscita.
///
/// Prima questi valori nascevano sparsi dentro il `build` della vista giorno,
/// ognuno con le sue condizioni: erano la ragione per cui i numeri della
/// giornata non si capivano e non si potevano testare.
DayExitView resolveDayExitView({
  required DaySchedule effectiveSchedule,
  required DaySchedule quickEditorSchedule,
  required UserWorkRules workRules,
  required String scheduledEndTimeText,
  required String rawStartTimeText,
  required String rawEndTimeText,
  required bool isDayOff,
  required bool isToday,
  required bool hasResultContext,
  required bool hasSuggestionContext,
  required WorkdaySession? session,
  required int nowMinutes,
  required int? pendingConfirmationMinutes,
}) {
  // La pausa gia' fatta sposta l'uscita: fermarsi di piu' vuol dire uscire piu'
  // tardi, non lavorare meno.
  final actualBreakMinutes = isToday
      ? currentSessionBreakMinutes(session, nowMinutes)
      : 0;
  final suggestedLabel = resolveSuggestedExitLabel(
    effectiveSchedule: effectiveSchedule,
    quickEditorSchedule: quickEditorSchedule,
    workRules: workRules,
    rawStartTimeText: rawStartTimeText,
    rawEndTimeText: rawEndTimeText,
    actualBreakMinutes: actualBreakMinutes,
  );
  final suggestedTotalMinutes = resolveSuggestedExitTotalMinutes(
    effectiveSchedule: effectiveSchedule,
    quickEditorSchedule: quickEditorSchedule,
    workRules: workRules,
    rawStartTimeText: rawStartTimeText,
    actualBreakMinutes: actualBreakMinutes,
  );

  final scheduledEndMinutes = parseTimeInput(scheduledEndTimeText.trim());
  final hasScheduledExit = scheduledEndTimeText.trim().isNotEmpty;
  final remainingMinutes =
      !isDayOff && isToday && hasResultContext && scheduledEndMinutes != null
      ? scheduledEndMinutes - nowMinutes
      : null;

  final hasPendingConfirmation = pendingConfirmationMinutes != null;
  final hasSuggestedExit =
      !isDayOff &&
      !hasScheduledExit &&
      hasSuggestionContext &&
      suggestedLabel != '--:--' &&
      suggestedLabel != 'Libero';
  final candidateConfirmableMinutes =
      pendingConfirmationMinutes ?? suggestedTotalMinutes;

  return DayExitView(
    suggestedLabel: suggestedLabel,
    suggestedTotalMinutes: suggestedTotalMinutes,
    hasScheduledExit: hasScheduledExit,
    remainingMinutes: remainingMinutes,
    remainingLabel: buildRemainingToExitLabel(remainingMinutes),
    hasPendingConfirmation: hasPendingConfirmation,
    isForecast: hasPendingConfirmation || hasSuggestedExit,
    confirmableMinutes:
        candidateConfirmableMinutes == null ||
            candidateConfirmableMinutes >
                clampExitToDayEnd(candidateConfirmableMinutes)
        ? null
        : candidateConfirmableMinutes,
  );
}
