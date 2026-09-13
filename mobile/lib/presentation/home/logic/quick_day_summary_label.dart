// Riga che riassume il giorno quando la modifica rapida e' chiusa.

import 'package:work_hours_mobile/application/services/hour_input_parser.dart';

/// Cosa dice la modifica rapida da chiusa.
///
/// Serve a non dover aprire il riquadro per sapere come sta la giornata: chi
/// deve solo timbrare non lo apre mai.
String buildQuickDaySummaryLabel({
  required bool isDayOff,
  required bool hasResultContext,
  required int workedMinutes,
  required String startTimeText,
  required String endTimeText,
  required String plannedStartTimeText,
  required String plannedEndTimeText,
  required String targetText,
}) {
  if (isDayOff) {
    return 'Giornata libera';
  }

  if (hasResultContext) {
    return 'Lavorate ${formatHoursInput(workedMinutes)}';
  }

  final start = startTimeText.trim().isEmpty
      ? plannedStartTimeText.trim()
      : startTimeText.trim();
  final end = endTimeText.trim().isEmpty
      ? plannedEndTimeText.trim()
      : endTimeText.trim();
  final target = targetText.trim();
  if (start.isEmpty || end.isEmpty) {
    return target.isEmpty ? 'Da impostare' : '$target previste';
  }

  return target.isEmpty ? '$start-$end' : '$start-$end · $target previste';
}

/// Quanto manca all'uscita prevista, o che e' arrivata.
String? buildRemainingToExitLabel(int? remainingMinutes) {
  if (remainingMinutes == null) {
    return null;
  }

  return remainingMinutes > 0
      ? 'Mancano ${formatHoursInput(remainingMinutes)} all\'uscita prevista'
      : 'Uscita prevista raggiunta';
}
