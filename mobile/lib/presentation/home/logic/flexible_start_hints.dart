// Fasce d'ingresso mostrate quando la flessibilita in entrata e attiva.

import 'package:work_hours_mobile/application/services/time_input_parser.dart';
import 'package:work_hours_mobile/domain/models/weekday_target_minutes.dart';
import 'package:work_hours_mobile/presentation/home/logic/calendar_dates.dart';

String _rangeLabel({
  required String prefix,
  required int startMinutes,
  required int windowMinutes,
}) {
  final latestStartMinutes = startMinutes + windowMinutes;
  final overflowSuffix = latestStartMinutes >= (24 * 60) ? ' +1g' : '';
  final latest = formatTimeInput(latestStartMinutes % (24 * 60));
  return '$prefix ${formatTimeInput(startMinutes)} - $latest$overflowSuffix';
}

/// Una fascia per giorno lavorativo, oppure una sola riga sull'orario unico.
///
/// Lista vuota quando la flessibilita e spenta o non c'e un'entrata da cui
/// partire: chi legge non deve vedere una fascia inventata.
List<String> buildFlexibleStartRangeHints({
  required bool isFlexibleStartEnabled,
  required int windowMinutes,
  required List<WeekdayKey> workingDays,
  required String? Function(WeekdayKey weekday) weekdayStartTimeOf,
  required String? uniformStartTime,
}) {
  if (!isFlexibleStartEnabled || windowMinutes <= 0) {
    return const [];
  }

  final hints = <String>[
    for (final weekday in workingDays)
      if (parseTimeInput(weekdayStartTimeOf(weekday)) case final startMinutes?)
        _rangeLabel(
          prefix: compactWeekdayLabel(weekday),
          startMinutes: startMinutes,
          windowMinutes: windowMinutes,
        ),
  ];
  if (hints.isNotEmpty) {
    return hints;
  }

  final uniformStartMinutes = parseTimeInput(uniformStartTime);
  if (uniformStartMinutes == null) {
    return const [];
  }

  return [
    _rangeLabel(
      prefix: 'Fascia',
      startMinutes: uniformStartMinutes,
      windowMinutes: windowMinutes,
    ),
  ];
}
