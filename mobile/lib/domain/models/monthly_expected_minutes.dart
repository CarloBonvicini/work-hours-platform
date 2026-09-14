// Quando un giorno pesa sul saldo, e quanto del previsto di un mese e' maturato.

import 'package:work_hours_mobile/domain/models/profile.dart';
import 'package:work_hours_mobile/domain/models/schedule_override.dart';

/// Se un giorno pesa sul saldo.
///
/// Pesa ogni giorno passato da [trackingStartDate] (la prima registrazione) in
/// poi, anche senza niente di registrato: un giorno di lavoro saltato e'
/// debito. Oggi pesa appena ha qualcosa di registrato. I giorni prima della
/// prima registrazione non pesano mai, se no chi comincia a usare l'app a
/// meta' mese partirebbe in debito. Con [trackingStartDate] null non si sa da
/// quando si registra, e pesano tutti i giorni passati.
///
/// Le date sono ISO (yyyy-MM-dd), quindi si confrontano come testo.
bool dayCountsInBalance({
  required String isoDate,
  required String todayIsoDate,
  required String? trackingStartDate,
  required bool hasRegistrations,
}) {
  if (trackingStartDate != null && isoDate.compareTo(trackingStartDate) < 0) {
    return false;
  }
  final comparison = isoDate.compareTo(todayIsoDate);
  return comparison < 0 || (comparison == 0 && hasRegistrations);
}

/// Da quando si registra: il giorno della prima registrazione, oppure oggi se
/// non ce n'e' ancora nessuna.
String resolveTrackingStartDate({
  required Iterable<String> registeredDates,
  required DateTime today,
}) {
  var earliest = formatIsoDate(today);
  for (final date in registeredDates) {
    if (date.compareTo(earliest) < 0) {
      earliest = date;
    }
  }
  return earliest;
}

/// Quanto del previsto del mese e' gia' maturato e quanto deve ancora arrivare.
///
/// Matura cio' che pesa sul saldo ([dayCountsInBalance]); resta da fare cio'
/// che non e' ancora arrivato, oggi compreso finche' e' vuoto. I giorni prima
/// della prima registrazione restano fuori da tutti e due. Prima entrava tutto
/// il mese, e a meta' mese il saldo segnava come debito le ore di giorni che
/// non erano ancora arrivati.
({int maturedMinutes, int remainingMinutes}) splitMonthlyExpectedMinutes({
  required String month,
  required UserProfile profile,
  required List<ScheduleOverride> overrides,
  required Set<String> registeredDates,
  required DateTime today,
  String? trackingStartDate,
}) {
  final parts = month.split('-');
  final year = int.parse(parts[0]);
  final monthNumber = int.parse(parts[1]);
  final daysInMonth = DateTime(year, monthNumber + 1, 0).day;
  final overridesByDate = {for (final entry in overrides) entry.date: entry};
  final todayIsoDate = formatIsoDate(today);

  var matured = 0;
  var remaining = 0;
  for (var day = 1; day <= daysInMonth; day += 1) {
    final date = DateTime(year, monthNumber, day);
    final isoDate = formatIsoDate(date);
    final minutes =
        overridesByDate[isoDate]?.targetMinutes ??
        profile.weekdaySchedule.forDate(date).targetMinutes;
    final countsInBalance = dayCountsInBalance(
      isoDate: isoDate,
      todayIsoDate: todayIsoDate,
      trackingStartDate: trackingStartDate,
      hasRegistrations: registeredDates.contains(isoDate),
    );
    if (countsInBalance) {
      matured += minutes;
    } else if (isoDate.compareTo(todayIsoDate) >= 0) {
      remaining += minutes;
    }
  }

  return (maturedMinutes: matured, remainingMinutes: remaining);
}

String formatIsoDate(DateTime date) {
  final year = date.year.toString().padLeft(4, '0');
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}
