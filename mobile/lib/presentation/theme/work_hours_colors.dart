// I colori che vogliono dire qualcosa, in un posto solo.

import 'package:flutter/material.dart';

/// Le tinte con un significato: credito, debito, previsione, allarmi.
///
/// Prima erano scritte a mano nei widget (nove copie del verde, sette del
/// rosso, due dell'ambra, piu' un secondo rosso diverso dagli altri): bastava
/// aggiungere una schermata perche' gli stessi concetti cambiassero colore.
///
/// Credito e debito sono una polarita' rispetto a uno zero, quindi usano una
/// coppia divergente blu/rosso con il grigio a fare da "in pari", e non il
/// verde/rosso: quella coppia e' la piu' difficile da distinguere per chi non
/// vede bene i colori, ed e' anche la meno sobria. Le due tinte sono state
/// verificate con il validatore della palette in chiaro e in scuro: passano
/// banda di luminosita', saturazione, separazione per daltonismo e contrasto
/// sul fondo.
///
/// Il colore non porta mai il significato da solo: accanto c'e' sempre
/// l'etichetta ("Credito mensile") e una freccia.
@immutable
class WorkHoursColors extends ThemeExtension<WorkHoursColors> {
  const WorkHoursColors({
    required this.credit,
    required this.debit,
    required this.neutral,
    required this.forecast,
    required this.warning,
    required this.critical,
  });

  /// Sei avanti rispetto alle ore dovute.
  final Color credit;

  /// Sei indietro.
  final Color debit;

  /// Sei in pari: nessuna direzione da segnalare.
  final Color neutral;

  /// Valore previsto, non ancora un fatto registrato.
  final Color forecast;

  /// Vicino a un limite.
  final Color warning;

  /// Oltre un limite.
  final Color critical;

  static const light = WorkHoursColors(
    credit: Color(0xFF1C5CAB),
    debit: Color(0xFFC43B36),
    neutral: Color(0xFF6B6A66),
    forecast: Color(0xFF5F6B7A),
    warning: Color(0xFFB8791F),
    critical: Color(0xFFC43B36),
  );

  static const dark = WorkHoursColors(
    credit: Color(0xFF3987E5),
    debit: Color(0xFFE66767),
    neutral: Color(0xFF9B9A94),
    forecast: Color(0xFF93A1B0),
    warning: Color(0xFFE0A63C),
    critical: Color(0xFFE66767),
  );

  /// Le tinte del tema corrente, con un ripiego se qualcuno scorda di registrarle.
  static WorkHoursColors of(BuildContext context) {
    return ofTheme(Theme.of(context));
  }

  /// Per chi ha gia' il tema in mano e non il `BuildContext`.
  static WorkHoursColors ofTheme(ThemeData theme) {
    return theme.extension<WorkHoursColors>() ??
        (theme.brightness == Brightness.dark ? dark : light);
  }

  /// Il colore di un saldo: avanti, indietro o in pari.
  Color forBalance(int balanceMinutes) {
    if (balanceMinutes == 0) {
      return neutral;
    }

    return balanceMinutes > 0 ? credit : debit;
  }

  @override
  WorkHoursColors copyWith({
    Color? credit,
    Color? debit,
    Color? neutral,
    Color? forecast,
    Color? warning,
    Color? critical,
  }) {
    return WorkHoursColors(
      credit: credit ?? this.credit,
      debit: debit ?? this.debit,
      neutral: neutral ?? this.neutral,
      forecast: forecast ?? this.forecast,
      warning: warning ?? this.warning,
      critical: critical ?? this.critical,
    );
  }

  @override
  WorkHoursColors lerp(ThemeExtension<WorkHoursColors>? other, double t) {
    if (other is! WorkHoursColors) {
      return this;
    }

    return WorkHoursColors(
      credit: Color.lerp(credit, other.credit, t)!,
      debit: Color.lerp(debit, other.debit, t)!,
      neutral: Color.lerp(neutral, other.neutral, t)!,
      forecast: Color.lerp(forecast, other.forecast, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      critical: Color.lerp(critical, other.critical, t)!,
    );
  }
}
