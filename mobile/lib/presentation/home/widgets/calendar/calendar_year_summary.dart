// Vista annuale con una card per mese.

import 'package:flutter/material.dart';
import 'package:work_hours_mobile/presentation/home/logic/calendar_dates.dart';
import 'package:work_hours_mobile/presentation/home/models/day_metrics.dart';

class CalendarYearSummary extends StatelessWidget {
  const CalendarYearSummary({
    super.key,
    required this.yearMetrics,
    required this.onOpenMonth,
  });

  final List<MonthMetrics> yearMetrics;
  final ValueChanged<String> onOpenMonth;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: yearMetrics
              .map(
                (metrics) => YearMonthCard(
                  metrics: metrics,
                  onTap: () => onOpenMonth(metrics.month),
                ),
              )
              .toList(growable: false),
        ),
      ],
    );
  }
}

class YearMonthCard extends StatelessWidget {
  const YearMonthCard({super.key, required this.metrics, required this.onTap});

  final MonthMetrics metrics;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SizedBox(
      width: 220,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Ink(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF162121) : const Color(0xFFF7F3EC),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  formatMonthLabel(metrics.month),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (metrics.overrideCount > 0) ...[
                  const SizedBox(height: 10),
                  Text(
                    metrics.overrideCount == 1
                        ? '1 modifica presente'
                        : '${metrics.overrideCount} modifiche presenti',
                    style: theme.textTheme.labelLarge,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
