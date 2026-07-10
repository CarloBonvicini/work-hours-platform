import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:work_hours_mobile/application/services/hour_input_parser.dart';
import 'package:work_hours_mobile/application/services/time_input_parser.dart';
import 'package:work_hours_mobile/domain/models/day_schedule.dart';
import 'package:work_hours_mobile/domain/models/leave_entry.dart';
import 'package:work_hours_mobile/domain/models/user_work_rules.dart';
import 'package:work_hours_mobile/domain/models/workday_session.dart';

/// Riepilogo residuo di una regola permessi/banca ore per la schermata Oggi.
class LeaveAllowanceSummary {
  const LeaveAllowanceSummary({
    required this.name,
    required this.remainingLabel,
  });

  final String name;
  final String remainingLabel;
}

int _ruleRemainingMinutes(WorkPermissionRule rule) {
  final safeUsed = math.min(rule.usedMinutes, rule.allowanceMinutes);
  return math.max(rule.allowanceMinutes - safeUsed, 0);
}

int _ruleRemainingDays(WorkPermissionRule rule) {
  final safeUsed = math.min(rule.usedDays, rule.allowanceDays);
  return math.max(rule.allowanceDays - safeUsed, 0);
}

String _formatDays(int days) {
  return days == 1 ? '1 g' : '$days gg';
}

String _ruleRemainingLabel(WorkPermissionRule rule) {
  switch (rule.allowanceType) {
    case WorkPermissionAllowanceType.hours:
      return formatHoursInput(_ruleRemainingMinutes(rule));
    case WorkPermissionAllowanceType.days:
      return _formatDays(_ruleRemainingDays(rule));
    case WorkPermissionAllowanceType.both:
      return '${_formatDays(_ruleRemainingDays(rule))} + ${formatHoursInput(_ruleRemainingMinutes(rule))}';
  }
}

/// Residui delle regole attive (banche ore prima, poi permessi extra).
List<LeaveAllowanceSummary> buildLeaveAllowanceSummaries(UserWorkRules rules) {
  return [
    for (final rule in [...rules.leaveBanks, ...rules.additionalPermissions])
      if (rule.enabled && rule.name.trim().isNotEmpty)
        LeaveAllowanceSummary(
          name: rule.name.trim(),
          remainingLabel: _ruleRemainingLabel(rule),
        ),
  ];
}

/// Elenco leggibile dei segmenti pausa registrati, inclusa quella in corso.
String? formatWorkdayBreakSegments(WorkdaySession? session, int nowMinutes) {
  if (session == null) {
    return null;
  }

  final parts = <String>[
    for (final segment in session.breakSegments)
      '${formatTimeInput(segment.startMinutes)}-${formatTimeInput(segment.endMinutes)}',
    if (session.isOnBreak)
      '${formatTimeInput(session.breakStartedMinutes!)}-in corso',
  ];

  if (parts.isEmpty) {
    return null;
  }

  return 'Pause: ${parts.join(' · ')}';
}

/// Fascia d'ingresso consentita quando la flessibilita in entrata e attiva.
String? resolveFlexibleEntryWindowLabel({
  required UserWorkRules workRules,
  required DaySchedule schedule,
}) {
  if (!workRules.fixedScheduleEnabled ||
      !workRules.flexibleStartEnabled ||
      workRules.flexibleStartWindowMinutes <= 0) {
    return null;
  }

  final startMinutes = parseTimeInput(schedule.startTime);
  if (startMinutes == null) {
    return null;
  }

  final latestStart = startMinutes + workRules.flexibleStartWindowMinutes;
  final normalizedLatest = latestStart % (24 * 60);
  return 'Fascia d ingresso: ${formatTimeInput(startMinutes)} - ${formatTimeInput(normalizedLatest)}';
}

/// Straordinario ancora ammesso oggi, se il massimale giornaliero e attivo.
int? resolveRemainingDailyOvertimeMinutes({
  required UserWorkRules workRules,
  required int rawBalanceMinutes,
}) {
  if (!workRules.overtimeEnabled ||
      !workRules.overtimeCapEnabled ||
      workRules.overtimeDailyCapMinutes <= 0) {
    return null;
  }

  return math.max(
    0,
    workRules.overtimeDailyCapMinutes - math.max(0, rawBalanceMinutes),
  );
}

class TodayExtrasCard extends StatelessWidget {
  const TodayExtrasCard({
    super.key,
    required this.isToday,
    required this.dayLeaveEntries,
    required this.allowances,
    required this.expectedMinutes,
    required this.workedMinutes,
    required this.leaveMinutes,
    required this.hasProgressContext,
    required this.remainingOvertimeMinutes,
    required this.onAddLeave,
  });

  final bool isToday;
  final List<LeaveEntry> dayLeaveEntries;
  final List<LeaveAllowanceSummary> allowances;
  final int expectedMinutes;
  final int workedMinutes;
  final int leaveMinutes;
  final bool hasProgressContext;
  final int? remainingOvertimeMinutes;
  final VoidCallback onAddLeave;

  bool get _showProgress =>
      expectedMinutes > 0 && (hasProgressContext || leaveMinutes > 0);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final registeredMinutes = workedMinutes + leaveMinutes;
    final missingMinutes = math.max(0, expectedMinutes - registeredMinutes);
    final progressValue = expectedMinutes <= 0
        ? 0.0
        : (registeredMinutes / expectedMinutes).clamp(0.0, 1.0).toDouble();

    final sections = <Widget>[];

    sections.add(
      Wrap(
        spacing: 10,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            isToday ? 'Causali di oggi' : 'Causali del giorno',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          if (dayLeaveEntries.isEmpty)
            Text(
              'Nessuna',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            )
          else
            for (final entry in dayLeaveEntries)
              Chip(
                key: ValueKey('today-leave-chip-${entry.id}'),
                avatar: Icon(switch (entry.type) {
                  LeaveType.vacation => Icons.beach_access_outlined,
                  LeaveType.permit => Icons.timer_outlined,
                  LeaveType.sickness => Icons.sick_outlined,
                }, size: 18),
                label: Text(
                  '${entry.type.label} ${formatHoursInput(entry.minutes)}',
                ),
              ),
          ActionChip(
            key: const ValueKey('today-add-leave-chip'),
            avatar: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Aggiungi causale'),
            onPressed: onAddLeave,
          ),
        ],
      ),
    );

    if (_showProgress) {
      sections.add(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                key: const ValueKey('today-progress-bar'),
                value: progressValue,
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              missingMinutes > 0
                  ? '${formatHoursInput(registeredMinutes)} su ${formatHoursInput(expectedMinutes)} - mancano ${formatHoursInput(missingMinutes)}'
                  : registeredMinutes == expectedMinutes
                  ? 'Obiettivo raggiunto (${formatHoursInput(expectedMinutes)})'
                  : 'Obiettivo superato di ${formatHoursInput(registeredMinutes - expectedMinutes)}',
              key: const ValueKey('today-progress-label'),
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            if (remainingOvertimeMinutes != null &&
                registeredMinutes >= expectedMinutes)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  remainingOvertimeMinutes! > 0
                      ? 'Straordinario ancora disponibile oggi: ${formatHoursInput(remainingOvertimeMinutes!)}'
                      : 'Massimale straordinario di oggi raggiunto.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
      );
    }

    if (allowances.isNotEmpty) {
      sections.add(
        Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              'Residui',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            for (final allowance in allowances)
              Chip(
                key: ValueKey('today-allowance-${allowance.name}'),
                avatar: const Icon(Icons.savings_outlined, size: 18),
                label: Text('${allowance.name}: ${allowance.remainingLabel}'),
              ),
          ],
        ),
      );
    }

    return Material(
      color: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var index = 0; index < sections.length; index += 1) ...[
              if (index > 0) const SizedBox(height: 14),
              sections[index],
            ],
          ],
        ),
      ),
    );
  }
}
