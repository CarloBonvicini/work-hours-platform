// Ore previste di un mese, divise fra giorni maturati e giorni ancora da fare.

import 'package:work_hours_mobile/domain/models/profile.dart';
import 'package:work_hours_mobile/domain/models/schedule_override.dart';

/// Quanto del previsto del mese e' gia' maturato e quanto deve ancora arrivare.
///
/// Matura ogni giorno gia' passato; [today] matura appena ha una data in
/// [registeredDates]. Prima entrava tutto il mese, e a meta' mese il saldo
/// segnava come debito le ore di giorni che non erano ancora arrivati.
({int maturedMinutes, int remainingMinutes}) splitMonthlyExpectedMinutes({
  required String month,
  required UserProfile profile,
  required List<ScheduleOverride> overrides,
  required Set<String> registeredDates,
  required DateTime today,
}) {
  final parts = month.split('-');
  final year = int.parse(parts[0]);
  final monthNumber = int.parse(parts[1]);
  final daysInMonth = DateTime(year, monthNumber + 1, 0).day;
  final overridesByDate = {for (final entry in overrides) entry.date: entry};
  final todayDate = DateTime(today.year, today.month, today.day);

  var matured = 0;
  var remaining = 0;
  for (var day = 1; day <= daysInMonth; day += 1) {
    final date = DateTime(year, monthNumber, day);
    final isoDate = _isoDate(date);
    final minutes =
        overridesByDate[isoDate]?.targetMinutes ??
        profile.weekdaySchedule.forDate(date).targetMinutes;
    final hasMatured =
        date.isBefore(todayDate) ||
        (date == todayDate && registeredDates.contains(isoDate));
    if (hasMatured) {
      matured += minutes;
    } else {
      remaining += minutes;
    }
  }

  return (maturedMinutes: matured, remainingMinutes: remaining);
}

String _isoDate(DateTime date) {
  final year = date.year.toString().padLeft(4, '0');
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}
