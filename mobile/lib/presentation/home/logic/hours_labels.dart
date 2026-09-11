// Etichette per durate, saldi e pause espresse in minuti.

import 'package:flutter/material.dart';
import 'package:work_hours_mobile/application/services/hour_input_parser.dart';

String formatHours(int minutes, {bool signed = false}) {
  final absoluteHours = minutes.abs() / 60;
  final formattedHours = absoluteHours == absoluteHours.truncateToDouble()
      ? absoluteHours.toStringAsFixed(0)
      : absoluteHours.toStringAsFixed(1);

  if (!signed) {
    return '${minutes < 0 ? '-' : ''}${formattedHours}h';
  }

  if (minutes == 0) {
    return '0h';
  }

  final prefix = minutes > 0 ? '+' : '-';
  return '$prefix${formattedHours}h';
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
  if (balanceMinutes == 0) {
    return Theme.of(context).colorScheme.primary;
  }

  return balanceMinutes > 0 ? const Color(0xFF0B6E69) : const Color(0xFF9D3D2F);
}
