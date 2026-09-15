// Credito o debito del periodo, con la scelta fra mese e settimana.

import 'package:flutter/material.dart';
import 'package:work_hours_mobile/application/services/hour_input_parser.dart';
import 'package:work_hours_mobile/application/services/theme_preference_store.dart';
import 'package:work_hours_mobile/presentation/home/logic/quick_day_insights.dart';

/// Il saldo del periodo: l'etichetta e' anche il selettore del periodo.
class QuickDayPeriodBalance extends StatelessWidget {
  const QuickDayPeriodBalance({
    super.key,
    required this.info,
    required this.aggregation,
    required this.onAggregationChanged,
    required this.labelStyle,
    required this.valueStyle,
    required this.neutralColor,
  });

  final DisplayedPeriodBalanceInfo info;
  final DayBalanceAggregation aggregation;
  final ValueChanged<DayBalanceAggregation> onAggregationChanged;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;
  final Color neutralColor;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final periodSuffix = switch (aggregation) {
      DayBalanceAggregation.monthly => 'mensile',
      DayBalanceAggregation.weekly => 'settimanale',
    };
    final label = switch (info.balanceMinutes) {
      > 0 => 'Credito $periodSuffix',
      < 0 => 'Debito $periodSuffix',
      _ => 'In pari $periodSuffix',
    };
    final color = switch (info.balanceMinutes) {
      > 0 => const Color(0xFF0B6E69),
      < 0 => const Color(0xFF9D3D2F),
      _ => neutralColor,
    };
    final value = info.balanceMinutes == 0
        ? '0:00'
        : formatHoursInput(info.balanceMinutes.abs());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PopupMenuButton<DayBalanceAggregation>(
          key: const ValueKey('calendar-live-period-balance-menu'),
          tooltip: 'Scegli periodo saldo',
          onSelected: onAggregationChanged,
          itemBuilder: (context) => const [
            PopupMenuItem(
              value: DayBalanceAggregation.monthly,
              child: Text('Mensile'),
            ),
            PopupMenuItem(
              value: DayBalanceAggregation.weekly,
              child: Text('Settimanale'),
            ),
          ],
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  label,
                  key: const ValueKey('calendar-live-period-balance-label'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: labelStyle,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 16,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          key: const ValueKey('calendar-live-expected-value'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: valueStyle?.copyWith(fontSize: 16, color: color),
        ),
      ],
    );
  }
}
