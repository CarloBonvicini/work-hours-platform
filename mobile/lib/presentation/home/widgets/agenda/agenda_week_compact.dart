// Panoramica compatta della settimana in agenda.

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:work_hours_mobile/presentation/theme/work_hours_colors.dart';
import 'package:work_hours_mobile/application/services/dashboard_service.dart';
import 'package:work_hours_mobile/application/services/hour_input_parser.dart';
import 'package:work_hours_mobile/application/services/time_input_parser.dart';
import 'package:work_hours_mobile/application/services/workday_start_store.dart';
import 'package:work_hours_mobile/presentation/home/logic/agenda_segments.dart';
import 'package:work_hours_mobile/presentation/home/logic/calendar_dates.dart';
import 'package:work_hours_mobile/presentation/home/logic/calendar_day_labels.dart';
import 'package:work_hours_mobile/presentation/home/logic/schedule_draft.dart';
import 'package:work_hours_mobile/presentation/home/models/agenda_range.dart';
import 'package:work_hours_mobile/presentation/home/models/calendar_day.dart';
import 'package:work_hours_mobile/presentation/home/models/day_metrics.dart';

class AgendaWeekCompactOverview extends StatelessWidget {
  const AgendaWeekCompactOverview({
    super.key,
    required this.metrics,
    required this.todayWorkdaySession,
    required this.onOpenDay,
  });

  final List<DayMetrics> metrics;
  final WorkdaySession? todayWorkdaySession;
  final Future<void> Function(DateTime date) onOpenDay;

  @override
  Widget build(BuildContext context) {
    final overviewRange = resolveAgendaRangeForSchedules(
      metrics.map((day) => day.schedule),
    );
    final now = DateTime.now();
    final nowMinutes = (now.hour * 60) + now.minute;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < metrics.length; index += 1) ...[
          (() {
            final day = metrics[index];
            final isToday = isSameDay(day.date, DateUtils.dateOnly(now));
            final effectiveSession = isToday ? todayWorkdaySession : null;
            return CompactWeekTimelineRow(
              metrics: day,
              range: overviewRange,
              measurementSegments: buildAgendaMeasurementSegments(
                schedule: day.schedule,
                session: effectiveSession,
                nowMinutes: nowMinutes,
              ),
              workdaySession: effectiveSession,
              onTap: () => unawaited(onOpenDay(day.date)),
            );
          })(),
          if (index < metrics.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class CompactWeekTimelineRow extends StatelessWidget {
  const CompactWeekTimelineRow({
    super.key,
    required this.metrics,
    required this.range,
    required this.measurementSegments,
    required this.workdaySession,
    this.onTap,
  });

  final DayMetrics metrics;
  final AgendaRange range;
  final List<AgendaMeasurementSegment> measurementSegments;
  final WorkdaySession? workdaySession;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final schedule = metrics.schedule;
    final startMinutes = parseTimeInput(schedule.startTime);
    final endMinutes = parseTimeInput(schedule.endTime);
    final hasStructuredSchedule =
        startMinutes != null && endMinutes != null && endMinutes > startMinutes;
    final effectiveSegments = hasStructuredSchedule
        ? resolveEffectiveAgendaSegments(
            startMinutes: startMinutes,
            endMinutes: endMinutes,
            measurementSegments: measurementSegments,
          )
        : const <AgendaMeasurementSegment>[];
    final workColor = metrics.hasOverride
        ? colorScheme.secondary.withValues(alpha: 0.28)
        : colorScheme.primary.withValues(alpha: 0.26);
    final pauseColor = colorScheme.secondary.withValues(alpha: 0.56);
    final rowBorderColor = metrics.hasOverride
        ? colorScheme.secondary.withValues(alpha: 0.45)
        : colorScheme.outlineVariant;
    final rowFillColor = metrics.hasOverride
        ? Color.lerp(
            colorScheme.surfaceContainerLow,
            colorScheme.secondary,
            0.1,
          )!
        : colorScheme.surfaceContainerLow;
    final relation = switch (compareDateToToday(metrics.date)) {
      0 => CalendarDayRelation.today,
      < 0 => CalendarDayRelation.past,
      _ => CalendarDayRelation.future,
    };
    final dayDetails = buildCalendarDayDetails(
      relation: relation,
      schedule: schedule,
      workedMinutes: metrics.workedMinutes,
      leaveMinutes: metrics.leaveMinutes,
      session: relation == CalendarDayRelation.today ? workdaySession : null,
    );
    final helperText = schedule.targetMinutes <= 0
        ? 'Giorno libero'
        : compactWeekScheduleLabel(schedule);
    final effectiveWorkedMinutes =
        relation == CalendarDayRelation.today && workdaySession == null
        ? metrics.workedMinutes
        : (dayDetails?.workedMinutes ?? metrics.workedMinutes);
    final hasRegisteredWorkOrLeave =
        effectiveWorkedMinutes > 0 || metrics.leaveMinutes > 0;
    final workedDeltaMinutes = hasRegisteredWorkOrLeave
        ? (effectiveWorkedMinutes + metrics.leaveMinutes) -
              metrics.expectedMinutes
        : 0;
    final isCurrentWithoutRegistrations =
        relation != CalendarDayRelation.future &&
        !hasRegisteredWorkOrLeave &&
        schedule.targetMinutes > 0;
    final workedLabelColor = workedDeltaMinutes >= 0
        ? WorkHoursColors.of(context).credit
        : WorkHoursColors.of(context).debit;
    final footerColor = isCurrentWithoutRegistrations
        ? colorScheme.onSurfaceVariant
        : workedLabelColor;
    final workedFooterLabel = dayDetails == null
        ? null
        : isCurrentWithoutRegistrations
        ? 'Nessuna timbratura'
        : 'Ore ${formatHoursInput(effectiveWorkedMinutes)}';
    final balanceFooterLabel = isCurrentWithoutRegistrations
        ? relation == CalendarDayRelation.past
              ? 'Da registrare'
              : 'Da iniziare'
        : workedDeltaMinutes > 0
        ? 'Credito: ${formatHoursInput(workedDeltaMinutes)}'
        : workedDeltaMinutes < 0
        ? 'Debito: ${formatHoursInput(workedDeltaMinutes.abs())}'
        : 'In pari';

    final rowContent = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 76,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                formatWeekdayShortLabel(metrics.date),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                formatCompactDate(metrics.date),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            key: ValueKey(
              'calendar-week-row-${DashboardService.defaultEntryDateOf(metrics.date)}',
            ),
            height: 60,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: rowFillColor,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: rowBorderColor),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                double leftForMinute(int minute) {
                  if (range.totalMinutes <= 0) {
                    return 0;
                  }
                  final clamped = minute.clamp(
                    range.startMinutes,
                    range.endMinutes,
                  );
                  return ((clamped - range.startMinutes) / range.totalMinutes) *
                      constraints.maxWidth;
                }

                return Stack(
                  children: [
                    for (final mark in range.hourMarks)
                      Positioned(
                        left: leftForMinute(mark),
                        top: 0,
                        bottom: 0,
                        child: Container(
                          width: 1,
                          color: colorScheme.outlineVariant.withValues(
                            alpha: 0.24,
                          ),
                        ),
                      ),
                    if (!hasStructuredSchedule)
                      Center(
                        child: Text(
                          helperText,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    if (hasStructuredSchedule) ...[
                      for (final segment in effectiveSegments)
                        Positioned(
                          left: leftForMinute(segment.startMinutes),
                          top: 16,
                          width: math.max(
                            10,
                            leftForMinute(segment.endMinutes) -
                                leftForMinute(segment.startMinutes),
                          ),
                          height: 18,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color:
                                  segment.kind ==
                                      AgendaMeasurementSegmentKind.pause
                                  ? pauseColor
                                  : workColor,
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                      Positioned(
                        left: 0,
                        top: 0,
                        child: Text(
                          formatTimeInput(startMinutes),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Text(
                          formatTimeInput(endMinutes),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: hasStructuredSchedule && dayDetails != null
                            ? Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      workedFooterLabel!,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(
                                            color: footerColor,
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      balanceFooterLabel,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.right,
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(
                                            color: footerColor,
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                  ),
                                ],
                              )
                            : Text(
                                helperText,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );

    if (onTap == null) {
      return rowContent;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: rowContent,
      ),
    );
  }
}
