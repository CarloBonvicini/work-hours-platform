// Giornate che hanno l'orario ma non le ore registrate.

import 'package:work_hours_mobile/domain/models/day_schedule.dart';
import 'package:work_hours_mobile/presentation/home/logic/day_balance.dart';

/// Ore che risultano dall'orario del giorno e che nessuno ha ancora registrato.
///
/// Entrata e uscita di un giorno passato raccontano una giornata fatta, ma le
/// ore valgono solo se sono registrate: sono due dati diversi e possono non
/// coincidere, per esempio quando l'uscita e' stata timbrata da una versione
/// dell'app che non le trasformava in una registrazione.
///
/// Restituisce `null` quando non c'e' niente da segnalare: oggi (la giornata e'
/// ancora in corso), una giornata libera, ore gia' registrate, o un orario che
/// non produce ore.
int? resolveUnrecordedWorkedMinutes({
  required bool isToday,
  required bool isDayOff,
  required int recordedWorkedMinutes,
  required DaySchedule schedule,
  required int minimumBreakMinutes,
}) {
  if (isToday || isDayOff || recordedWorkedMinutes > 0) {
    return null;
  }

  final workedMinutes = resolveComputedWorkedMinutes(
    schedule: schedule,
    minimumBreakMinutes: minimumBreakMinutes,
  );
  if (workedMinutes == null || workedMinutes <= 0) {
    return null;
  }

  return workedMinutes;
}
