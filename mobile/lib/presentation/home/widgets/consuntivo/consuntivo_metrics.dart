// Griglia e riquadri dei valori del consuntivo.

import 'package:flutter/material.dart';
import 'package:work_hours_mobile/presentation/home/models/consuntivo_summary.dart';

class ConsuntivoMetricGrid extends StatelessWidget {
  const ConsuntivoMetricGrid({super.key, required this.totals});

  final ConsuntivoTotals totals;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        ConsuntivoMetricTile(
          label: 'Previste finora',
          value: formatConsuntivoMetricHours(totals.expectedMinutes),
        ),
        if (totals.remainingExpectedMinutes > 0)
          ConsuntivoMetricTile(
            label: 'Ancora da fare',
            value: formatConsuntivoMetricHours(totals.remainingExpectedMinutes),
          ),
        ConsuntivoMetricTile(
          label: 'Lavorate',
          value: formatConsuntivoMetricHours(totals.workedMinutes),
        ),
        ConsuntivoMetricTile(
          label: 'Causali',
          value: formatConsuntivoMetricHours(totals.leaveMinutes),
        ),
        ConsuntivoMetricTile(
          label: 'Saldo reale',
          value: formatConsuntivoMetricSignedHours(totals.rawBalanceMinutes),
        ),
        ConsuntivoMetricTile(
          label: 'Saldo controllato',
          value: formatConsuntivoMetricSignedHours(
            totals.clampedBalanceMinutes,
          ),
        ),
        ConsuntivoMetricTile(
          label: 'Straordinario maturato',
          value: formatConsuntivoMetricHours(totals.overtimeMaturedMinutes),
          positive: true,
        ),
        ConsuntivoMetricTile(
          label: 'Debito maturato',
          value: formatConsuntivoMetricHours(totals.debitMaturedMinutes),
        ),
      ],
    );
  }
}

class ConsuntivoMetricTile extends StatelessWidget {
  const ConsuntivoMetricTile({
    super.key,
    required this.label,
    required this.value,
    this.positive = false,
  });

  final String label;
  final String value;
  final bool positive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 160,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: theme.colorScheme.surfaceContainerLow,
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.labelMedium),
          const SizedBox(height: 6),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: positive ? const Color(0xFF0B6E69) : null,
            ),
          ),
        ],
      ),
    );
  }
}

String formatConsuntivoMetricHours(int minutes) {
  final absoluteMinutes = minutes.abs();
  final hours = absoluteMinutes ~/ 60;
  final remainingMinutes = absoluteMinutes % 60;
  final prefix = minutes < 0 ? '-' : '';
  return '$prefix$hours:${remainingMinutes.toString().padLeft(2, '0')}';
}

String formatConsuntivoMetricSignedHours(int minutes) {
  if (minutes == 0) {
    return '0:00';
  }
  final prefix = minutes > 0 ? '+' : '-';
  return '$prefix${formatConsuntivoMetricHours(minutes.abs())}';
}
