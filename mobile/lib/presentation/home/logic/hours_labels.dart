// Etichette per durate, saldi e pause espresse in minuti.

import 'package:flutter/material.dart';
import 'package:work_hours_mobile/presentation/theme/work_hours_colors.dart';
import 'package:work_hours_mobile/application/services/hour_input_parser.dart';

/// Una durata, sempre nella stessa forma: `8:00`, `0:30`, `-1:15`.
///
/// Prima convivevano due formati (`8h` e `8:00`, piu' `60 min` per le pause):
/// tre modi di scrivere la stessa cosa nella stessa schermata.
String formatHours(int minutes, {bool signed = false}) {
  if (signed) {
    return formatSignedHoursInput(minutes);
  }

  return '${minutes < 0 ? '-' : ''}${formatHoursInput(minutes.abs())}';
}

String formatSignedHoursInput(int minutes) {
  if (minutes == 0) {
    return '0:00';
  }

  final prefix = minutes > 0 ? '+' : '-';
  return '$prefix${formatHoursInput(minutes.abs())}';
}

String formatBreakInput(int minutes) {
  return minutes == 0 ? '' : formatHoursInput(minutes);
}

Color balanceColor(BuildContext context, int balanceMinutes) {
  return WorkHoursColors.of(context).forBalance(balanceMinutes);
}
