// Riga di un'attivita recente.

import 'package:flutter/material.dart';
import 'package:work_hours_mobile/presentation/home/logic/hours_labels.dart';
import 'package:work_hours_mobile/presentation/home/models/activity_item.dart';

class ActivityRow extends StatelessWidget {
  const ActivityRow({super.key, required this.item});

  final ActivityItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: item.accentColor.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(item.icon, color: item.accentColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(item.subtitle, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 6),
              Text(item.date, style: theme.textTheme.labelMedium),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Text(
          formatHours(item.minutes),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: item.accentColor,
          ),
        ),
      ],
    );
  }
}
