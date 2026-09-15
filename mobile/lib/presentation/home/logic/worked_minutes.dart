// La regola unica: quali pause si scalano dalle ore lavorate.

import 'dart:math' as math;

/// La pausa che si scala dalle ore.
///
/// Vale quella registrata nel giorno — le pause timbrate per la giornata in
/// corso, il campo Pausa per un giorno gia' chiuso — e mai meno del minimo
/// imposto dalle regole di lavoro.
///
/// La pausa del piano settimanale non entra qui. E' una previsione, e le
/// previsioni non fanno ore (`mobile/AGENTS.md`): serve a proporre l'uscita e a
/// precompilare il campo Pausa del giorno, non a decidere quanto hai lavorato.
int resolveCountedBreakMinutes({
  required int recordedBreakMinutes,
  int minimumBreakMinutes = 0,
}) {
  return math.max<int>(
    math.max<int>(0, recordedBreakMinutes),
    math.max<int>(0, minimumBreakMinutes),
  );
}

/// Ore lavorate: presenza meno la pausa che conta.
///
/// Un posto solo, cosi' il contatore dal vivo, le ore che l'uscita registra e
/// quelle che rileggi riaprendo il giorno sono per forza lo stesso numero.
int resolveWorkedMinutes({
  required int presenceMinutes,
  required int recordedBreakMinutes,
  int minimumBreakMinutes = 0,
}) {
  return math.max<int>(
    0,
    presenceMinutes -
        resolveCountedBreakMinutes(
          recordedBreakMinutes: recordedBreakMinutes,
          minimumBreakMinutes: minimumBreakMinutes,
        ),
  );
}
