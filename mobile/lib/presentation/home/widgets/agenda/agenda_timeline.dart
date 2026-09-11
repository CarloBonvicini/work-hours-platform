// Timeline giornaliera e settimanale dell'agenda: intestazioni e binario delle ore.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:work_hours_mobile/application/services/time_input_parser.dart';
import 'package:work_hours_mobile/application/services/workday_start_store.dart';
import 'package:work_hours_mobile/domain/models/day_schedule.dart';
import 'package:work_hours_mobile/presentation/home/logic/agenda_segments.dart';
import 'package:work_hours_mobile/presentation/home/logic/calendar_dates.dart';
import 'package:work_hours_mobile/presentation/home/models/agenda_range.dart';
import 'package:work_hours_mobile/presentation/home/models/day_metrics.dart';
import 'package:work_hours_mobile/presentation/home/widgets/agenda/agenda_day_surface.dart';
import 'package:work_hours_mobile/presentation/home/widgets/agenda/agenda_schedule_block.dart';

class AgendaDayTimeline extends StatefulWidget {
  const AgendaDayTimeline({
    super.key,
    required this.metrics,
    required this.range,
    required this.schedule,
    required this.isProvisional,
    required this.measurementSegments,
    required this.onPreviewChanged,
    required this.onPreviewCleared,
    required this.onScheduleChanged,
    required this.onInteractionChanged,
  });

  final DayMetrics metrics;
  final AgendaRange range;
  final DaySchedule schedule;
  final bool isProvisional;
  final List<AgendaMeasurementSegment> measurementSegments;
  final void Function({
    required int startMinutes,
    required int endMinutes,
    int? breakMinutes,
    int? pauseStartMinutes,
    int? pauseEndMinutes,
  })
  onPreviewChanged;
  final VoidCallback onPreviewCleared;
  final void Function({
    required int startMinutes,
    required int endMinutes,
    int? breakMinutes,
    int? pauseStartMinutes,
    int? pauseEndMinutes,
  })
  onScheduleChanged;
  final ValueChanged<bool> onInteractionChanged;

  @override
  State<AgendaDayTimeline> createState() => AgendaDayTimelineState();
}

class AgendaDayTimelineState extends State<AgendaDayTimeline> {
  AgendaRange? _lockedRange;

  @override
  void didUpdateWidget(covariant AgendaDayTimeline oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.schedule.startTime != oldWidget.schedule.startTime ||
        widget.schedule.endTime != oldWidget.schedule.endTime ||
        widget.schedule.breakMinutes != oldWidget.schedule.breakMinutes) {
      _lockedRange = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final baseTimelineHeight = widget.range.timelineHeight(
      pixelsPerHour: 30,
      minHeight: 260,
    );
    final effectiveRange = _lockedRange ?? widget.range;
    final timelineHeight = baseTimelineHeight;

    return SizedBox(
      height: timelineHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AgendaHourRail(range: effectiveRange, height: timelineHeight),
          const SizedBox(width: 12),
          Expanded(
            child: AgendaDaySurface(
              metrics: widget.metrics,
              schedule: widget.schedule,
              range: effectiveRange,
              height: timelineHeight,
              displayMode: AgendaSurfaceDisplayMode.day,
              isProvisional: widget.isProvisional,
              measurementSegments: widget.measurementSegments,
              onPreviewChanged:
                  ({
                    required int startMinutes,
                    required int endMinutes,
                    int? breakMinutes,
                    int? pauseStartMinutes,
                    int? pauseEndMinutes,
                  }) {
                    setState(() {
                      _lockedRange ??= widget.range;
                    });
                    widget.onPreviewChanged(
                      startMinutes: startMinutes,
                      endMinutes: endMinutes,
                      breakMinutes: breakMinutes,
                      pauseStartMinutes: pauseStartMinutes,
                      pauseEndMinutes: pauseEndMinutes,
                    );
                  },
              onPreviewCleared: () {
                if (!mounted) {
                  return;
                }
                setState(() {
                  _lockedRange = null;
                });
                widget.onPreviewCleared();
              },
              onScheduleChanged: widget.onScheduleChanged,
              onInteractionChanged: widget.onInteractionChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class AgendaWeekTimeline extends StatelessWidget {
  const AgendaWeekTimeline({
    super.key,
    required this.metrics,
    required this.selectedDate,
    required this.todayWorkdaySession,
    required this.onOpenDay,
    required this.range,
  });

  final List<DayMetrics> metrics;
  final DateTime selectedDate;
  final WorkdaySession? todayWorkdaySession;
  final Future<void> Function(DateTime date) onOpenDay;
  final AgendaRange range;

  @override
  Widget build(BuildContext context) {
    const headerHeight = 74.0;
    const columnWidth = 134.0;
    final timelineHeight = range.timelineHeight(
      pixelsPerHour: 18,
      minHeight: 180,
    );
    final now = DateTime.now();
    final nowMinutes = (now.hour * 60) + now.minute;

    return SizedBox(
      height: headerHeight + 10 + timelineHeight,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 52,
              child: Column(
                children: [
                  const SizedBox(height: headerHeight),
                  const SizedBox(height: 10),
                  AgendaHourRail(range: range, height: timelineHeight),
                ],
              ),
            ),
            const SizedBox(width: 12),
            for (final day in metrics) ...[
              (() {
                final isToday = isSameDay(day.date, DateUtils.dateOnly(now));
                final effectiveSession = isToday ? todayWorkdaySession : null;
                return SizedBox(
                  width: columnWidth,
                  child: Column(
                    children: [
                      SizedBox(
                        height: headerHeight,
                        child: AgendaDayHeader(
                          metrics: day,
                          isSelected: isSameDay(day.date, selectedDate),
                          onTap: () => unawaited(onOpenDay(day.date)),
                        ),
                      ),
                      const SizedBox(height: 10),
                      AgendaDaySurface(
                        metrics: day,
                        schedule: day.schedule,
                        range: range,
                        height: timelineHeight,
                        displayMode: AgendaSurfaceDisplayMode.week,
                        isSelected: isSameDay(day.date, selectedDate),
                        measurementSegments: buildAgendaMeasurementSegments(
                          schedule: day.schedule,
                          session: effectiveSession,
                          nowMinutes: nowMinutes,
                        ),
                        onTap: () => unawaited(onOpenDay(day.date)),
                      ),
                    ],
                  ),
                );
              })(),
              if (day != metrics.last) const SizedBox(width: 12),
            ],
          ],
        ),
      ),
    );
  }
}

class AgendaDayHeader extends StatelessWidget {
  const AgendaDayHeader({
    super.key,
    required this.metrics,
    required this.isSelected,
    required this.onTap,
  });

  final DayMetrics metrics;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final backgroundColor = isSelected
        ? colorScheme.primary
        : colorScheme.surface;
    final borderColor = isSelected
        ? colorScheme.primary
        : colorScheme.outlineVariant;
    final primaryTextColor = isSelected
        ? colorScheme.onPrimary
        : colorScheme.onSurface;
    final secondaryTextColor = isSelected
        ? colorScheme.onPrimary.withValues(alpha: 0.86)
        : theme.textTheme.bodySmall?.color?.withValues(alpha: 0.78) ??
              colorScheme.onSurface.withValues(alpha: 0.78);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Ink(
          width: double.infinity,
          height: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor, width: isSelected ? 1.4 : 1),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                formatWeekdayShortLabel(metrics.date),
                style: theme.textTheme.labelLarge?.copyWith(
                  color: secondaryTextColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                formatCompactDate(metrics.date),
                style: theme.textTheme.titleMedium?.copyWith(
                  color: primaryTextColor,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AgendaHourRail extends StatelessWidget {
  const AgendaHourRail({super.key, required this.range, required this.height});

  final AgendaRange range;
  final double height;

  @override
  Widget build(BuildContext context) {
    final labelStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
      fontWeight: FontWeight.w600,
      color: Theme.of(
        context,
      ).textTheme.bodySmall?.color?.withValues(alpha: 0.78),
    );

    return SizedBox(
      width: 52,
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (final mark in range.hourMarks)
            Positioned(
              top: resolveAgendaLabelTop(
                range.positionFor(mark, height),
                height,
              ),
              right: 0,
              child: Text(formatTimeInput(mark), style: labelStyle),
            ),
        ],
      ),
    );
  }
}
