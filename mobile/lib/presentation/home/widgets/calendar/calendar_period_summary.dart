// Riepilogo del periodo selezionato (giorno/settimana) sotto il calendario.

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:work_hours_mobile/application/services/time_input_parser.dart';
import 'package:work_hours_mobile/application/services/workday_start_store.dart';
import 'package:work_hours_mobile/domain/models/day_schedule.dart';
import 'package:work_hours_mobile/presentation/home/logic/agenda_segments.dart';
import 'package:work_hours_mobile/presentation/home/logic/calendar_dates.dart';
import 'package:work_hours_mobile/presentation/home/models/agenda_range.dart';
import 'package:work_hours_mobile/presentation/home/models/calendar_day.dart';
import 'package:work_hours_mobile/presentation/home/models/calendar_view.dart';
import 'package:work_hours_mobile/presentation/home/models/day_metrics.dart';
import 'package:work_hours_mobile/presentation/home/widgets/agenda/agenda_timeline.dart';
import 'package:work_hours_mobile/presentation/home/widgets/agenda/agenda_week_compact.dart';
import 'package:work_hours_mobile/presentation/home/widgets/calendar/calendar_month_summary.dart';
import 'package:work_hours_mobile/presentation/home/widgets/calendar/calendar_year_summary.dart';

class CalendarPeriodSummary extends StatelessWidget {
  const CalendarPeriodSummary({
    super.key,
    required this.calendarView,
    required this.days,
    required this.dayMetrics,
    required this.daySchedule,
    required this.dayPauseWindow,
    required this.isDayScheduleProvisional,
    required this.workdaySession,
    required this.weekMetrics,
    required this.monthMetrics,
    required this.yearMetrics,
    required this.selectedDate,
    required this.onSelectDate,
    required this.onOpenDay,
    required this.onCalendarViewChanged,
    required this.onDaySchedulePreviewChanged,
    required this.onDaySchedulePreviewCleared,
    required this.onDayScheduleChanged,
    required this.onAgendaInteractionChanged,
    required this.isDayAgendaExpanded,
    required this.onToggleDayAgendaExpanded,
  });

  final CalendarView calendarView;
  final List<CalendarDay> days;
  final DayMetrics dayMetrics;
  final DaySchedule daySchedule;
  final CalendarPauseWindow? dayPauseWindow;
  final bool isDayScheduleProvisional;
  final WorkdaySession? workdaySession;
  final List<DayMetrics> weekMetrics;
  final MonthMetrics monthMetrics;
  final List<MonthMetrics> yearMetrics;
  final DateTime selectedDate;
  final ValueChanged<DateTime> onSelectDate;
  final Future<void> Function(DateTime date) onOpenDay;
  final Future<void> Function(CalendarView view) onCalendarViewChanged;
  final void Function({
    required int startMinutes,
    required int endMinutes,
    int? breakMinutes,
    int? pauseStartMinutes,
    int? pauseEndMinutes,
  })
  onDaySchedulePreviewChanged;
  final VoidCallback onDaySchedulePreviewCleared;
  final void Function({
    required int startMinutes,
    required int endMinutes,
    int? breakMinutes,
    int? pauseStartMinutes,
    int? pauseEndMinutes,
  })
  onDayScheduleChanged;
  final ValueChanged<bool> onAgendaInteractionChanged;
  final bool isDayAgendaExpanded;
  final ValueChanged<bool> onToggleDayAgendaExpanded;

  @override
  Widget build(BuildContext context) {
    return switch (calendarView) {
      CalendarView.day => CalendarDaySummary(
        metrics: dayMetrics,
        schedule: daySchedule,
        pauseWindow: dayPauseWindow,
        isProvisional: isDayScheduleProvisional,
        workdaySession: workdaySession,
        onSchedulePreviewChanged: onDaySchedulePreviewChanged,
        onSchedulePreviewCleared: onDaySchedulePreviewCleared,
        onScheduleChanged: onDayScheduleChanged,
        onAgendaInteractionChanged: onAgendaInteractionChanged,
        isExpanded: isDayAgendaExpanded,
        onToggleExpanded: onToggleDayAgendaExpanded,
      ),
      CalendarView.week => CalendarWeekSummary(
        metrics: weekMetrics,
        selectedDate: selectedDate,
        todayWorkdaySession: workdaySession,
        onOpenDay: onOpenDay,
      ),
      CalendarView.month => CalendarMonthSummary(
        days: days,
        monthMetrics: monthMetrics,
        onOpenDay: onOpenDay,
      ),
      CalendarView.year => CalendarYearSummary(
        yearMetrics: yearMetrics,
        onOpenMonth: (month) {
          onSelectDate(monthToDate(month));
          unawaited(onCalendarViewChanged(CalendarView.month));
        },
      ),
    };
  }
}

class CalendarDaySummary extends StatelessWidget {
  const CalendarDaySummary({
    super.key,
    required this.metrics,
    required this.schedule,
    required this.pauseWindow,
    required this.isProvisional,
    required this.workdaySession,
    required this.onSchedulePreviewChanged,
    required this.onSchedulePreviewCleared,
    required this.onScheduleChanged,
    required this.onAgendaInteractionChanged,
    required this.isExpanded,
    required this.onToggleExpanded,
  });

  final DayMetrics metrics;
  final DaySchedule schedule;
  final CalendarPauseWindow? pauseWindow;
  final bool isProvisional;
  final WorkdaySession? workdaySession;
  final void Function({
    required int startMinutes,
    required int endMinutes,
    int? breakMinutes,
    int? pauseStartMinutes,
    int? pauseEndMinutes,
  })
  onSchedulePreviewChanged;
  final VoidCallback onSchedulePreviewCleared;
  final void Function({
    required int startMinutes,
    required int endMinutes,
    int? breakMinutes,
    int? pauseStartMinutes,
    int? pauseEndMinutes,
  })
  onScheduleChanged;
  final ValueChanged<bool> onAgendaInteractionChanged;
  final bool isExpanded;
  final ValueChanged<bool> onToggleExpanded;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final nowMinutes = (now.hour * 60) + now.minute;
    final measurementSegments = buildAgendaMeasurementSegments(
      schedule: schedule,
      session: workdaySession,
      nowMinutes: nowMinutes,
      pauseWindow: pauseWindow,
    );
    final scheduledStartMinutes = parseTimeInput(schedule.startTime);
    final scheduledEndMinutes = parseTimeInput(schedule.endTime);
    final hasStructuredSchedule =
        scheduledStartMinutes != null &&
        scheduledEndMinutes != null &&
        scheduledEndMinutes > scheduledStartMinutes;
    final hasMeasuredSegments = measurementSegments.isNotEmpty;
    final agendaRange = resolveCompactAgendaRangeForBounds(
      startMinutes: hasStructuredSchedule
          ? scheduledStartMinutes
          : (hasMeasuredSegments
                ? measurementSegments
                      .map((segment) => segment.startMinutes)
                      .reduce(math.min)
                : null),
      endMinutes: hasStructuredSchedule
          ? scheduledEndMinutes
          : (hasMeasuredSegments
                ? measurementSegments
                      .map((segment) => segment.endMinutes)
                      .reduce(math.max)
                : null),
    );
    final hasAgendaTimeline = hasStructuredSchedule || hasMeasuredSegments;
    final workedSummary = buildAgendaWorkedSummary(
      measurementSegments: measurementSegments,
    );
    final toggleButton = IconButton(
      key: const ValueKey('calendar-day-agenda-toggle-button'),
      onPressed: () => onToggleExpanded(!isExpanded),
      tooltip: isExpanded ? 'Riduci agenda' : 'Espandi agenda',
      visualDensity: VisualDensity.compact,
      iconSize: isExpanded ? 20 : 18,
      splashRadius: isExpanded ? 18 : 16,
      constraints: BoxConstraints.tightFor(
        width: isExpanded ? 36 : 30,
        height: isExpanded ? 36 : 30,
      ),
      padding: EdgeInsets.zero,
      icon: Icon(
        isExpanded
            ? Icons.keyboard_arrow_up_rounded
            : Icons.keyboard_arrow_down_rounded,
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => onToggleExpanded(!isExpanded),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    'Agenda oraria',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
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
                    if (hasAgendaTimeline)
                      AgendaDayTimeline(
                        metrics: metrics,
                        range: agendaRange,
                        schedule: schedule,
                        isProvisional: isProvisional,
                        measurementSegments: measurementSegments,
                        onPreviewChanged: onSchedulePreviewChanged,
                        onPreviewCleared: onSchedulePreviewCleared,
                        onScheduleChanged: onScheduleChanged,
                        onInteractionChanged: onAgendaInteractionChanged,
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 8,
                        ),
                        child: Text(
                          'Nessun orario da mostrare. Inserisci entrata e uscita per vedere la timeline.',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                    if (workedSummary != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        workedSummary,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class CalendarWeekSummary extends StatelessWidget {
  const CalendarWeekSummary({
    super.key,
    required this.metrics,
    required this.selectedDate,
    required this.todayWorkdaySession,
    required this.onOpenDay,
  });

  final List<DayMetrics> metrics;
  final DateTime selectedDate;
  final WorkdaySession? todayWorkdaySession;
  final Future<void> Function(DateTime date) onOpenDay;

  @override
  Widget build(BuildContext context) {
    final agendaRange = resolveAgendaRange(metrics);

    return LayoutBuilder(
      builder: (context, constraints) {
        final useCompactLayout = constraints.maxWidth < 760;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Agenda settimanale',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            if (useCompactLayout)
              AgendaWeekCompactOverview(
                metrics: metrics,
                todayWorkdaySession: todayWorkdaySession,
                onOpenDay: onOpenDay,
              )
            else
              AgendaWeekTimeline(
                metrics: metrics,
                selectedDate: selectedDate,
                todayWorkdaySession: todayWorkdaySession,
                onOpenDay: onOpenDay,
                range: agendaRange,
              ),
          ],
        );
      },
    );
  }
}
