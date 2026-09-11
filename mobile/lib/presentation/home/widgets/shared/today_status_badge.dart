// Badge dello stato della giornata.

import 'package:flutter/material.dart';
import 'package:work_hours_mobile/presentation/home/models/day_metrics.dart';

class TodayStatusBadge extends StatelessWidget {
  const TodayStatusBadge({
    super.key,
    required this.label,
    required this.color,
    required this.icon,
  });

  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

({String label, IconData icon, Color color}) todayStatusMeta(
  BuildContext context,
  TodayStatus status,
) {
  return switch (status) {
    TodayStatus.dayOff => (
      label: 'Libero',
      icon: Icons.free_breakfast_outlined,
      color: Theme.of(context).colorScheme.secondary,
    ),
    TodayStatus.planned => (
      label: 'Pianificata',
      icon: Icons.schedule_outlined,
      color: Theme.of(context).colorScheme.primary,
    ),
    TodayStatus.needsAttention => (
      label: 'Da completare',
      icon: Icons.priority_high_outlined,
      color: const Color(0xFF9D3D2F),
    ),
    TodayStatus.inProgress => (
      label: 'In corso',
      icon: Icons.play_circle_outline,
      color: const Color(0xFF0B6E69),
    ),
    TodayStatus.completed => (
      label: 'Completata',
      icon: Icons.check_circle_outline,
      color: const Color(0xFF0B6E69),
    ),
    TodayStatus.absent => (
      label: 'Assenza registrata',
      icon: Icons.event_busy_outlined,
      color: Theme.of(context).colorScheme.secondary,
    ),
  };
}
