// Cosa vuol dire ogni numero della schermata, e dove si cambia.

import 'package:work_hours_mobile/presentation/home/models/home_section.dart';

/// I valori che si possono interrogare tenendo premuto.
enum ExplainableValue {
  worked,
  dayBalance,
  overtime,
  periodBalance,
  monthBalance,
  dayTarget,
  dayBreak,
  entryTime,
  exitTime,
}

/// Spiegazione di un numero: cosa dice, da dove esce, dove si cambia.
class ValueExplanation {
  const ValueExplanation({
    required this.title,
    required this.meaning,
    required this.source,
    this.settingsSection,
    this.settingsHint,
  });

  /// Come si chiama a schermo.
  final String title;

  /// Cosa rappresenta, in parole di tutti i giorni.
  final String meaning;

  /// Da dove esce il numero: la domanda che nessuna schermata sa rispondere.
  final String source;

  /// Dove si va a cambiarlo, se si puo' cambiare.
  final HomeSection? settingsSection;

  /// Il riquadro da cercare una volta arrivati.
  final String? settingsHint;
}

/// Il testo di ogni valore, in un posto solo.
///
/// Sta in `logic/` e non nei widget perche' e' contenuto, non presentazione:
/// cosi' si legge tutto insieme e si controlla che parli la stessa lingua.
ValueExplanation explanationFor(ExplainableValue value) {
  switch (value) {
    case ExplainableValue.worked:
      return const ValueExplanation(
        title: 'Lavorate',
        meaning: 'Le ore che risultano registrate per questo giorno.',
        source:
            'Presenza meno pausa. La pausa che conta e\' quella registrata nel '
            'giorno: quella timbrata se la giornata e\' in corso, il campo '
            'Pausa se e\' gia\' chiusa. Non scende mai sotto la Pausa minima.',
        settingsSection: HomeSection.workSettings,
        settingsHint: 'Regole del contratto',
      );
    case ExplainableValue.dayBalance:
      return const ValueExplanation(
        title: 'Saldo di oggi',
        meaning:
            'Quanto sei avanti o indietro rispetto alle ore che devi fare oggi.',
        source: 'Ore lavorate meno ore da fare oggi.',
        settingsSection: HomeSection.workSettings,
        settingsHint: 'Orario settimanale',
      );
    case ExplainableValue.overtime:
      return const ValueExplanation(
        title: 'Straordinario',
        meaning: 'Le ore fatte oltre quelle dovute, se le tieni attive.',
        source:
            'Conta solo il tempo oltre le ore da fare, e solo se lo '
            'straordinario e\' abilitato nelle regole.',
        settingsSection: HomeSection.workSettings,
        settingsHint: 'Regole del contratto',
      );
    case ExplainableValue.periodBalance:
      return const ValueExplanation(
        title: 'Credito o debito del periodo',
        meaning:
            'La somma dei saldi dei giorni: in credito hai fatto piu\' ore del '
            'dovuto, in debito ne mancano.',
        source:
            'Somma i saldi di tutti i giorni del periodo scelto. Il periodo si '
            'cambia toccando l\'etichetta.',
        settingsSection: HomeSection.workSettings,
        settingsHint: 'Orario settimanale',
      );
    case ExplainableValue.monthBalance:
      return const ValueExplanation(
        title: 'Saldo del mese',
        meaning: 'Ore registrate nel mese sul totale che il mese richiede.',
        source:
            'Il primo numero sono le ore registrate, il secondo la somma delle '
            'ore da fare nei giorni lavorativi del mese.',
        settingsSection: HomeSection.workSettings,
        settingsHint: 'Orario settimanale',
      );
    case ExplainableValue.dayTarget:
      return const ValueExplanation(
        title: 'Ore di lavoro',
        meaning: 'Le ore che devi fare in questa giornata.',
        source:
            'Arrivano dal piano settimanale. Cambiarle qui vale solo per questo '
            'giorno, il piano resta com\'e\'.',
        settingsSection: HomeSection.workSettings,
        settingsHint: 'Orario settimanale',
      );
    case ExplainableValue.dayBreak:
      return const ValueExplanation(
        title: 'Pausa',
        meaning: 'La pausa di questa giornata.',
        source:
            'Si scala dalle ore lavorate. Se timbri le pause vale quella vera; '
            'in ogni caso non scende sotto la Pausa minima delle regole.',
        settingsSection: HomeSection.workSettings,
        settingsHint: 'Regole del contratto',
      );
    case ExplainableValue.entryTime:
      return const ValueExplanation(
        title: 'Entrata',
        meaning: 'L\'ora in cui hai iniziato.',
        source:
            'Se l\'hai timbrata e\' un dato di fatto. Se invece e\' solo '
            'proposta arriva dal piano settimanale, e la puoi correggere.',
        settingsSection: HomeSection.workSettings,
        settingsHint: 'Orario settimanale',
      );
    case ExplainableValue.exitTime:
      return const ValueExplanation(
        title: 'Uscita',
        meaning:
            'L\'ora in cui hai finito, oppure quella prevista se non hai ancora '
            'finito.',
        source:
            'L\'uscita prevista la calcola l\'app: entrata piu\' ore da fare '
            'piu\' pausa. Non e\' una registrazione finche\' non la confermi.',
        settingsSection: HomeSection.workSettings,
        settingsHint: 'Orario settimanale',
      );
  }
}
