// La legenda che dice quando un valore e' un fatto e quando una previsione.

import 'package:flutter/material.dart';
import 'package:work_hours_mobile/presentation/theme/work_hours_colors.dart';

/// Spiega i due stati che la schermata mostra fianco a fianco.
///
/// Registrato e previsto si somigliavano troppo: tre colori diversi a schermo e
/// nessuna spiegazione. La differenza non la porta il colore da solo - il
/// previsto e' anche tratteggiato e si chiama "prevista" per esteso - ma senza
/// dirlo da qualche parte resta un codice da indovinare.
class RecordedForecastLegend extends StatelessWidget {
  const RecordedForecastLegend({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = WorkHoursColors.of(context);
    final style = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w600,
    );

    return Wrap(
      key: const ValueKey('recorded-forecast-legend'),
      spacing: 16,
      runSpacing: 6,
      children: [
        _LegendEntry(
          color: theme.colorScheme.onSurface,
          label: 'Registrato',
          isDashed: false,
          style: style,
        ),
        _LegendEntry(
          color: palette.forecast,
          label: 'Previsto',
          isDashed: true,
          style: style,
        ),
      ],
    );
  }
}

class _LegendEntry extends StatelessWidget {
  const _LegendEntry({
    required this.color,
    required this.label,
    required this.isDashed,
    required this.style,
  });

  final Color color;
  final String label;
  final bool isDashed;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 3,
          decoration: BoxDecoration(
            color: isDashed ? null : color,
            borderRadius: BorderRadius.circular(2),
            border: isDashed ? Border.all(color: color, width: 1.2) : null,
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: style),
      ],
    );
  }
}
