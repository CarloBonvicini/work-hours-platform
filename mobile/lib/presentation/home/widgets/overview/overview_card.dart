// Card panoramica della giornata con preset di modifica rapida.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:work_hours_mobile/domain/models/day_schedule.dart';
import 'package:work_hours_mobile/domain/models/schedule_override.dart';
import 'package:work_hours_mobile/presentation/home/logic/calendar_dates.dart';
import 'package:work_hours_mobile/presentation/home/logic/hours_labels.dart';
import 'package:work_hours_mobile/presentation/home/logic/schedule_draft.dart';
import 'package:work_hours_mobile/presentation/home/models/activity_item.dart';
import 'package:work_hours_mobile/presentation/home/models/day_metrics.dart';
import 'package:work_hours_mobile/presentation/home/widgets/overview/today_reminder_card.dart';
import 'package:work_hours_mobile/presentation/home/widgets/shared/activity_row.dart';
import 'package:work_hours_mobile/presentation/home/widgets/shared/section_cards.dart';
import 'package:work_hours_mobile/presentation/home/widgets/shared/today_status_badge.dart';

enum TodayOverridePreset { startLater, finishEarlier, longerBreak, dayOff }

class OverviewCard extends StatelessWidget {
  const OverviewCard({
    super.key,
    required this.selectedDate,
    required this.todayMetrics,
    required this.todayStatus,
    required this.effectiveSchedule,
    required this.todayOverride,
    required this.todayActivities,
    required this.reminders,
    required this.onOpenWorkEntry,
    required this.onOpenLeaveEntry,
    required this.onOpenTodayCalendar,
    required this.onApplyPreset,
    this.onRemoveTodayOverride,
  });

  final DateTime selectedDate;
  final DayMetrics todayMetrics;
  final TodayStatus todayStatus;
  final DaySchedule effectiveSchedule;
  final ScheduleOverride? todayOverride;
  final List<ActivityItem> todayActivities;
  final List<({IconData icon, String title, String description})> reminders;
  final VoidCallback onOpenWorkEntry;
  final VoidCallback onOpenLeaveEntry;
  final Future<void> Function() onOpenTodayCalendar;
  final Future<void> Function(TodayOverridePreset preset) onApplyPreset;
  final Future<void> Function()? onRemoveTodayOverride;

  @override
  Widget build(BuildContext context) {
    final registeredMinutes =
        todayMetrics.workedMinutes + todayMetrics.leaveMinutes;
    final remainingMinutes = (todayMetrics.expectedMinutes - registeredMinutes)
        .clamp(0, 24 * 60);
    final statusMeta = todayStatusMeta(context, todayStatus);
    final primaryAction = _primaryAction();

    return SectionCard(
      title: 'Oggi',
      subtitle:
          'Controlla subito come e organizzata la giornata e fai solo la prossima azione utile.',
      trailing: TodayStatusBadge(
        label: statusMeta.label,
        color: statusMeta.color,
        icon: statusMeta.icon,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InlineInfoPanel(
            title: formatLongDate(selectedDate),
            description: formatDayScheduleDetails(effectiveSchedule),
            statusText: todayOverride == null
                ? 'Programma standard di oggi'
                : 'Programma personalizzato per oggi',
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              MetricCard(
                icon: Icons.flag_outlined,
                label: 'Previsto oggi',
                value: formatHours(todayMetrics.expectedMinutes),
              ),
              MetricCard(
                icon: Icons.schedule_outlined,
                label: 'Registrato',
                value: formatHours(registeredMinutes),
              ),
              MetricCard(
                icon: Icons.pending_actions_outlined,
                label: 'Ancora da fare',
                value: formatHours(remainingMinutes),
              ),
              MetricCard(
                icon: Icons.compare_arrows_outlined,
                label: 'Scostamento',
                value: formatHours(todayMetrics.balanceMinutes, signed: true),
                accentColor: balanceColor(context, todayMetrics.balanceMinutes),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'Prossima azione',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: primaryAction.onPressed,
            icon: Icon(primaryAction.icon),
            label: Text(primaryAction.label),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              OutlinedButton.icon(
                onPressed: onOpenWorkEntry,
                icon: const Icon(Icons.work_history_outlined),
                label: const Text('Registra lavoro'),
              ),
              OutlinedButton.icon(
                onPressed: onOpenLeaveEntry,
                icon: const Icon(Icons.event_busy_outlined),
                label: const Text('Segna assenza'),
              ),
              OutlinedButton.icon(
                onPressed: () => onOpenTodayCalendar(),
                icon: const Icon(Icons.edit_calendar_outlined),
                label: const Text('Apri giorno'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'Eccezioni guidate',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              ActionChip(
                label: const Text('Entro piu tardi'),
                onPressed: () =>
                    unawaited(onApplyPreset(TodayOverridePreset.startLater)),
              ),
              ActionChip(
                label: const Text('Esco prima'),
                onPressed: () =>
                    unawaited(onApplyPreset(TodayOverridePreset.finishEarlier)),
              ),
              ActionChip(
                label: const Text('Pausa diversa'),
                onPressed: () =>
                    unawaited(onApplyPreset(TodayOverridePreset.longerBreak)),
              ),
              ActionChip(
                label: const Text('Oggi non lavoro'),
                onPressed: () =>
                    unawaited(onApplyPreset(TodayOverridePreset.dayOff)),
              ),
              if (onRemoveTodayOverride != null)
                ActionChip(
                  label: const Text('Ripristina standard'),
                  onPressed: () => unawaited(onRemoveTodayOverride!()),
                ),
            ],
          ),
          if (reminders.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              'Promemoria di oggi',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            for (var index = 0; index < reminders.length; index += 1) ...[
              TodayReminderCard(
                icon: reminders[index].icon,
                title: reminders[index].title,
                description: reminders[index].description,
              ),
              if (index < reminders.length - 1) const SizedBox(height: 10),
            ],
          ],
          const SizedBox(height: 20),
          Text(
            'Attivita di oggi',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          if (todayActivities.isEmpty)
            Text(
              'Nessuna registrazione per oggi.',
              style: Theme.of(context).textTheme.bodyLarge,
            )
          else
            Column(
              children: [
                for (
                  var index = 0;
                  index < todayActivities.length;
                  index += 1
                ) ...[
                  ActivityRow(item: todayActivities[index]),
                  if (index < todayActivities.length - 1)
                    const Divider(height: 22),
                ],
              ],
            ),
        ],
      ),
    );
  }

  ({String label, IconData icon, VoidCallback onPressed}) _primaryAction() {
    return switch (todayStatus) {
      TodayStatus.dayOff => (
        label: 'Controlla il giorno',
        icon: Icons.calendar_month_outlined,
        onPressed: () => unawaited(onOpenTodayCalendar()),
      ),
      TodayStatus.planned => (
        label: 'Registra la giornata di oggi',
        icon: Icons.play_arrow_outlined,
        onPressed: onOpenWorkEntry,
      ),
      TodayStatus.needsAttention => (
        label: 'Completa la giornata',
        icon: Icons.task_alt_outlined,
        onPressed: onOpenWorkEntry,
      ),
      TodayStatus.inProgress => (
        label: 'Aggiorna le ore di oggi',
        icon: Icons.schedule_send_outlined,
        onPressed: onOpenWorkEntry,
      ),
      TodayStatus.completed => (
        label: 'Rivedi la giornata',
        icon: Icons.visibility_outlined,
        onPressed: () => unawaited(onOpenTodayCalendar()),
      ),
      TodayStatus.absent => (
        label: 'Gestisci l assenza di oggi',
        icon: Icons.event_note_outlined,
        onPressed: onOpenLeaveEntry,
      ),
    };
  }
}
