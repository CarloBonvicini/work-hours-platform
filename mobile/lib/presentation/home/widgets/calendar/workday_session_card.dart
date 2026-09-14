// Card della timbratura (entrata, pausa, uscita) del giorno.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:work_hours_mobile/application/services/time_input_parser.dart';
import 'package:work_hours_mobile/application/services/workday_start_store.dart';
import 'package:work_hours_mobile/domain/models/day_schedule.dart';
import 'package:work_hours_mobile/presentation/home/logic/workday_session_info.dart';
import 'package:work_hours_mobile/presentation/home/models/calendar_day.dart';
import 'package:work_hours_mobile/presentation/home/widgets/shared/today_status_badge.dart';

class WorkdaySessionCard extends StatelessWidget {
  const WorkdaySessionCard({
    super.key,
    required this.isExpanded,
    required this.session,
    required this.schedule,
    required this.pauseWindow,
    required this.isBusy,
    required this.onToggleExpanded,
    required this.onRecordNow,
    required this.onStartBreak,
    required this.onResume,
    required this.onFinish,
    this.flexibleEntryWindowLabel,
    this.onClear,
  });

  final bool isExpanded;
  final WorkdaySession? session;
  final DaySchedule schedule;
  final CalendarPauseWindow? pauseWindow;
  final bool isBusy;
  final ValueChanged<bool> onToggleExpanded;
  final Future<void> Function() onRecordNow;
  final Future<void> Function() onStartBreak;
  final Future<void> Function() onResume;
  final Future<void> Function() onFinish;
  final String? flexibleEntryWindowLabel;
  final Future<void> Function()? onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final nowMinutes = (now.hour * 60) + now.minute;
    final status = resolveWorkdaySessionStatus(session);
    final statusMeta = workdaySessionStatusMeta(context, status);
    final currentBreakMinutes = currentSessionBreakMinutes(session, nowMinutes);
    final expectedEndInfo = resolveExpectedEndInfo(
      session: session,
      schedule: schedule,
      nowMinutes: nowMinutes,
    );
    final workedSessionInfo = resolveWorkedSessionInfo(
      session: session,
      nowMinutes: nowMinutes,
    );
    final breakSegmentsInfo = formatWorkdayBreakSegments(session);
    // L'uscita si annuncia solo a giornata chiusa: l'orario previsto resta una
    // previsione, non una registrazione.
    final displayedEndMinutes = session?.isCompleted == true
        ? (parseTimeInput(schedule.endTime) ?? session?.endMinutes)
        : null;
    final toggleButtonSize = isExpanded ? 36.0 : 30.0;
    final toggleIconSize = isExpanded ? 20.0 : 18.0;
    final expandedIcon = isExpanded
        ? Icons.keyboard_arrow_up_rounded
        : Icons.keyboard_arrow_down_rounded;
    final toggleButton = IconButton(
      key: const ValueKey('calendar-workday-card-toggle-button'),
      onPressed: () => onToggleExpanded(!isExpanded),
      tooltip: isExpanded ? 'Riduci riquadro' : 'Espandi riquadro',
      visualDensity: VisualDensity.compact,
      iconSize: toggleIconSize,
      splashRadius: isExpanded ? 18 : 16,
      constraints: BoxConstraints.tightFor(
        width: toggleButtonSize,
        height: toggleButtonSize,
      ),
      padding: EdgeInsets.zero,
      icon: Icon(expandedIcon),
    );

    if (!isExpanded) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => onToggleExpanded(true),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    'Entrata, pausa, uscita.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            toggleButton,
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => onToggleExpanded(false),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: FittedBox(
                      alignment: Alignment.centerLeft,
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.login_rounded,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Giornata di oggi',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              TodayStatusBadge(
                label: statusMeta.label,
                color: statusMeta.color,
                icon: statusMeta.icon,
              ),
              const SizedBox(width: 8),
              toggleButton,
            ],
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: isExpanded
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 10),
                      Text(
                        workdaySessionDescription(
                          session: session,
                          schedule: schedule,
                          pauseWindow: pauseWindow,
                          status: status,
                          currentBreakMinutes: currentBreakMinutes,
                        ),
                        style: theme.textTheme.bodyMedium,
                      ),
                      if (expectedEndInfo != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          expectedEndInfo,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                      if (workedSessionInfo != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          workedSessionInfo,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                      if (breakSegmentsInfo != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          breakSegmentsInfo,
                          key: const ValueKey(
                            'calendar-workday-break-segments',
                          ),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      if (status == WorkdaySessionStatus.notStarted &&
                          flexibleEntryWindowLabel != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          flexibleEntryWindowLabel!,
                          key: const ValueKey(
                            'calendar-workday-flexible-window',
                          ),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                      if (displayedEndMinutes != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          'Uscita registrata alle ${formatTimeInput(displayedEndMinutes)}.',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          if (session == null || session!.isCompleted)
                            FilledButton.icon(
                              key: const ValueKey(
                                'calendar-record-start-button',
                              ),
                              onPressed: isBusy ? null : onRecordNow,
                              icon: Icon(
                                session?.isCompleted == true
                                    ? Icons.login_rounded
                                    : Icons.play_arrow_rounded,
                              ),
                              // Giornata gia' chiusa: si rientra riaprendola,
                              // senza perdere entrata e pause registrate.
                              label: Text(
                                isBusy
                                    ? 'Salvo...'
                                    : session?.isCompleted == true
                                    ? 'Rientro'
                                    : 'Entrata',
                              ),
                            ),
                          if (session != null &&
                              !session!.isCompleted &&
                              !session!.isOnBreak)
                            FilledButton.tonalIcon(
                              key: const ValueKey(
                                'calendar-start-break-button',
                              ),
                              onPressed: isBusy ? null : onStartBreak,
                              icon: const Icon(Icons.coffee_outlined),
                              label: const Text('Inizio pausa'),
                            ),
                          if (session?.isOnBreak == true)
                            FilledButton.tonalIcon(
                              key: const ValueKey(
                                'calendar-resume-workday-button',
                              ),
                              onPressed: isBusy ? null : onResume,
                              icon: const Icon(
                                Icons.play_circle_outline_rounded,
                              ),
                              label: const Text('Fine pausa'),
                            ),
                          if (session != null && !session!.isCompleted)
                            FilledButton.icon(
                              key: const ValueKey(
                                'calendar-end-workday-button',
                              ),
                              onPressed: isBusy ? null : onFinish,
                              icon: const Icon(Icons.logout_rounded),
                              label: const Text('Uscita'),
                            ),
                          if (onClear != null)
                            OutlinedButton.icon(
                              key: const ValueKey(
                                'calendar-clear-workday-session-button',
                              ),
                              onPressed: isBusy ? null : onClear,
                              icon: const Icon(Icons.delete_outline),
                              label: const Text('Rimuovi'),
                            ),
                        ],
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

({String label, IconData icon, Color color}) workdaySessionStatusMeta(
  BuildContext context,
  WorkdaySessionStatus status,
) {
  return switch (status) {
    WorkdaySessionStatus.notStarted => (
      label: 'Da iniziare',
      icon: Icons.play_circle_outline,
      color: Theme.of(context).colorScheme.secondary,
    ),
    WorkdaySessionStatus.active => (
      label: 'Dentro',
      icon: Icons.badge_outlined,
      color: const Color(0xFF0B6E69),
    ),
    WorkdaySessionStatus.onBreak => (
      label: 'In pausa',
      icon: Icons.free_breakfast_outlined,
      color: Theme.of(context).colorScheme.secondary,
    ),
    WorkdaySessionStatus.completed => (
      label: 'Chiusa',
      icon: Icons.check_circle_outline,
      color: const Color(0xFF0B6E69),
    ),
  };
}
