// Griglia del mese: intestazione giorni e celle.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:work_hours_mobile/presentation/home/models/calendar_day.dart';
import 'package:work_hours_mobile/presentation/home/models/day_metrics.dart';
import 'package:work_hours_mobile/presentation/home/widgets/calendar/month_cell_summaries.dart';

class CalendarMonthSummary extends StatelessWidget {
  const CalendarMonthSummary({
    super.key,
    required this.days,
    required this.monthMetrics,
    required this.onOpenDay,
  });

  final List<CalendarDay> days;
  final MonthMetrics monthMetrics;
  final Future<void> Function(DateTime date) onOpenDay;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const WeekdayHeader(),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final isCompactCalendar = constraints.maxWidth < 420;
            final isUltraCompactCalendar = constraints.maxWidth < 460;

            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: days.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                crossAxisSpacing: isCompactCalendar ? 6 : 8,
                mainAxisSpacing: isCompactCalendar ? 6 : 8,
                childAspectRatio: isUltraCompactCalendar
                    ? 1.12
                    : isCompactCalendar
                    ? 0.9
                    : 0.82,
              ),
              itemBuilder: (context, index) {
                final day = days[index];
                return CalendarDayCell(
                  day: day,
                  isCompact: isCompactCalendar,
                  onTap: day.date == null
                      ? null
                      : () => unawaited(onOpenDay(day.date!)),
                );
              },
            );
          },
        ),
      ],
    );
  }
}

class WeekdayHeader extends StatelessWidget {
  const WeekdayHeader({super.key});

  @override
  Widget build(BuildContext context) {
    const weekDays = ['Lun', 'Mar', 'Mer', 'Gio', 'Ven', 'Sab', 'Dom'];

    return Row(
      children: weekDays
          .map(
            (label) => Expanded(
              child: Center(
                child: Text(
                  label,
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          )
          .toList(growable: false),
    );
  }
}

class CalendarDayCell extends StatelessWidget {
  const CalendarDayCell({
    super.key,
    required this.day,
    required this.isCompact,
    required this.onTap,
  });

  final CalendarDay day;
  final bool isCompact;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    if (day.date == null) {
      return const SizedBox.shrink();
    }

    final isSelected = day.isSelected;
    final baseBackgroundColor = switch (day.relation) {
      CalendarDayRelation.past => Color.lerp(
        colorScheme.surface,
        colorScheme.secondary,
        0.12,
      )!,
      CalendarDayRelation.today => Color.lerp(
        colorScheme.surface,
        colorScheme.primary,
        0.2,
      )!,
      CalendarDayRelation.future => Color.lerp(
        colorScheme.surface,
        colorScheme.tertiary,
        0.1,
      )!,
    };
    final backgroundColor = isSelected
        ? Color.lerp(baseBackgroundColor, colorScheme.primary, 0.18)!
        : baseBackgroundColor;
    final borderColor = switch (day.relation) {
      CalendarDayRelation.past => colorScheme.secondary,
      CalendarDayRelation.today => colorScheme.primary,
      CalendarDayRelation.future => colorScheme.tertiary,
    };
    final textColor = switch (day.relation) {
      CalendarDayRelation.past => colorScheme.onSecondaryContainer,
      CalendarDayRelation.today => colorScheme.onPrimaryContainer,
      CalendarDayRelation.future => colorScheme.onTertiaryContainer,
    };
    final detailColor = textColor.withValues(alpha: 0.88);
    final workColor = switch (day.relation) {
      CalendarDayRelation.past => colorScheme.secondary,
      CalendarDayRelation.today => colorScheme.primary,
      CalendarDayRelation.future => colorScheme.tertiary,
    };
    final pauseColor = Color.lerp(workColor, colorScheme.secondary, 0.6)!;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isUltraCompactCell = constraints.maxWidth < 68;
        final isMicroCell =
            constraints.maxWidth < 56 || constraints.maxHeight < 40;
        final isTinySummaryCell =
            isUltraCompactCell ||
            constraints.maxWidth < 86 ||
            constraints.maxHeight < 80;
        final isTooShortForSummary =
            constraints.maxHeight < 64 || constraints.maxWidth < 56;
        final dayNumberAlignment = isTooShortForSummary
            ? Alignment.center
            : Alignment.centerLeft;
        final cellPadding = isMicroCell
            ? 3.0
            : (isUltraCompactCell ? 5.0 : (isCompact ? 7.0 : 9.0));
        return Material(
          color: Colors.transparent,
          child: InkWell(
            key: ValueKey('calendar-day-${day.isoDate}'),
            borderRadius: BorderRadius.circular(18),
            onTap: onTap,
            child: Ink(
              padding: EdgeInsets.all(cellPadding),
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: borderColor,
                  width: isSelected || day.isToday ? 1.5 : 1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: borderColor.withValues(alpha: 0.14),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: Column(
                mainAxisAlignment: isTooShortForSummary
                    ? MainAxisAlignment.center
                    : MainAxisAlignment.start,
                crossAxisAlignment: isTooShortForSummary
                    ? CrossAxisAlignment.center
                    : CrossAxisAlignment.start,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: dayNumberAlignment,
                    child: Text(
                      '${day.date!.day}',
                      maxLines: 1,
                      softWrap: false,
                      style:
                          (isMicroCell
                                  ? Theme.of(context).textTheme.labelLarge
                                  : isUltraCompactCell
                                  ? Theme.of(context).textTheme.titleSmall
                                  : Theme.of(context).textTheme.titleMedium)
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: textColor,
                              ),
                    ),
                  ),
                  if (!isTooShortForSummary) ...[
                    SizedBox(
                      height: isMicroCell
                          ? 1
                          : (isUltraCompactCell ? 3 : (isCompact ? 4 : 6)),
                    ),
                    Expanded(
                      child: isTinySummaryCell
                          ? MonthCellTinySummary(
                              day: day,
                              details: day.details,
                              detailColor: detailColor,
                              workColor: workColor,
                              pauseColor: pauseColor,
                            )
                          : day.details == null
                          ? MonthCellFallback(
                              day: day,
                              detailColor: detailColor,
                            )
                          : MonthCellCompactSummary(
                              details: day.details!,
                              textColor: detailColor,
                              workColor: workColor,
                              pauseColor: pauseColor,
                            ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class MonthCellFallback extends StatelessWidget {
  const MonthCellFallback({
    super.key,
    required this.day,
    required this.detailColor,
  });

  final CalendarDay day;
  final Color detailColor;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomLeft,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (day.primaryLabel != null)
            Text(
              day.primaryLabel!,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: detailColor,
                fontWeight: FontWeight.w700,
                height: 1.05,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          if (day.secondaryLabel != null) ...[
            const SizedBox(height: 2),
            Text(
              day.secondaryLabel!,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: detailColor.withValues(alpha: 0.82),
                fontWeight: FontWeight.w600,
                height: 1.0,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}
