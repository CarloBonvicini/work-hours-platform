// Selettore del periodo e badge di relazione con oggi.

import 'package:flutter/material.dart';

class CalendarPeriodSwitcher extends StatelessWidget {
  const CalendarPeriodSwitcher({
    super.key,
    required this.periodLabel,
    required this.onPreviousPeriod,
    required this.onNextPeriod,
  });

  final String periodLabel;
  final VoidCallback onPreviousPeriod;
  final VoidCallback onNextPeriod;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = Theme.of(context).colorScheme;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 320),
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.max,
          children: [
            IconButton(
              key: const ValueKey('calendar-prev-month'),
              onPressed: onPreviousPeriod,
              icon: const Icon(Icons.chevron_left),
              visualDensity: VisualDensity.compact,
              iconSize: 20,
              splashRadius: 18,
              constraints: const BoxConstraints.tightFor(width: 36, height: 36),
              padding: EdgeInsets.zero,
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  periodLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            IconButton(
              key: const ValueKey('calendar-next-month'),
              onPressed: onNextPeriod,
              icon: const Icon(Icons.chevron_right),
              visualDensity: VisualDensity.compact,
              iconSize: 20,
              splashRadius: 18,
              constraints: const BoxConstraints.tightFor(width: 36, height: 36),
              padding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }
}

class CalendarDateRelationBadge extends StatelessWidget {
  const CalendarDateRelationBadge({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.7)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
