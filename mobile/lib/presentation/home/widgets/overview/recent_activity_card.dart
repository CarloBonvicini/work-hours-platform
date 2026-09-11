// Attivita recenti e piano della settimana.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:work_hours_mobile/domain/models/leave_entry.dart';
import 'package:work_hours_mobile/presentation/home/logic/calendar_dates.dart';
import 'package:work_hours_mobile/presentation/home/logic/schedule_draft.dart';
import 'package:work_hours_mobile/presentation/home/models/day_metrics.dart';
import 'package:work_hours_mobile/presentation/home/widgets/shared/section_cards.dart';
import 'package:work_hours_mobile/presentation/home/widgets/shared/today_status_badge.dart';

class RecentActivityCard extends StatelessWidget {
  const RecentActivityCard({
    super.key,
    required this.weekPlan,
    required this.onOpenDay,
    required this.onOpenWorkEntry,
    required this.onOpenLeaveEntry,
  });

  final List<WeekPlanDay> weekPlan;
  final Future<void> Function(DateTime date) onOpenDay;
  final void Function(DateTime date, {int? prefilledMinutes, String? note})
  onOpenWorkEntry;
  final void Function(
    DateTime date, {
    int? prefilledMinutes,
    LeaveType leaveType,
    String? note,
  })
  onOpenLeaveEntry;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Settimana',
      subtitle:
          'Controlla in pochi secondi i prossimi 7 giorni, con stato e fascia prevista.',
      child: Column(
        children: [
          for (var index = 0; index < weekPlan.length; index += 1) ...[
            WeekPlanRow(
              day: weekPlan[index],
              onOpenDay: () => onOpenDay(weekPlan[index].date),
              onOpenWorkEntry: () => onOpenWorkEntry(
                weekPlan[index].date,
                prefilledMinutes: weekPlan[index].metrics.expectedMinutes,
              ),
              onOpenLeaveEntry: () => onOpenLeaveEntry(
                weekPlan[index].date,
                prefilledMinutes: weekPlan[index].metrics.expectedMinutes == 0
                    ? null
                    : weekPlan[index].metrics.expectedMinutes,
                leaveType: LeaveType.permit,
              ),
            ),
            if (index < weekPlan.length - 1) const Divider(height: 22),
          ],
        ],
      ),
    );
  }
}

class WeekPlanRow extends StatelessWidget {
  const WeekPlanRow({
    super.key,
    required this.day,
    required this.onOpenDay,
    required this.onOpenWorkEntry,
    required this.onOpenLeaveEntry,
  });

  final WeekPlanDay day;
  final VoidCallback onOpenDay;
  final VoidCallback onOpenWorkEntry;
  final VoidCallback onOpenLeaveEntry;

  @override
  Widget build(BuildContext context) {
    final statusMeta = todayStatusMeta(context, day.status);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    formatLongDate(day.date),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formatScheduleWindowDetails(day.metrics.schedule),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            TodayStatusBadge(
              label: statusMeta.label,
              color: statusMeta.color,
              icon: statusMeta.icon,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            OutlinedButton.icon(
              onPressed: onOpenDay,
              icon: const Icon(Icons.visibility_outlined),
              label: const Text('Apri giorno'),
            ),
            OutlinedButton.icon(
              onPressed: onOpenWorkEntry,
              icon: const Icon(Icons.work_history_outlined),
              label: const Text('Registra'),
            ),
            OutlinedButton.icon(
              onPressed: onOpenLeaveEntry,
              icon: const Icon(Icons.event_busy_outlined),
              label: const Text('Assenza'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          'Spunta "Ore lavorate fisse" se vuoi che, quando aumenti la pausa in Oggi, '
          'l orario di uscita venga posticipato e le ore lavorative restino quelle impostate.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 6),
        Text(
          'Spunta "Uscita fissa" se vuoi che, quando aumenti la pausa in Oggi, '
          'l orario di uscita resti invariato e si riducano le ore lavorative.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
