// Contenuti compatti delle celle del calendario mensile.

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:work_hours_mobile/application/services/hour_input_parser.dart';
import 'package:work_hours_mobile/presentation/home/models/calendar_day.dart';

class MonthCellCompactSummary extends StatelessWidget {
  const MonthCellCompactSummary({
    super.key,
    required this.details,
    required this.textColor,
    required this.workColor,
    required this.pauseColor,
  });

  final CalendarDayDetails details;
  final Color textColor;
  final Color workColor;
  final Color pauseColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Center(
            child: MonthMiniTimeline(
              details: details,
              workColor: workColor,
              pauseColor: pauseColor,
            ),
          ),
        ),
        const SizedBox(height: 4),
        MonthDataToken(
          color: workColor,
          label: formatHoursInput(details.workedMinutes),
          textColor: textColor,
        ),
        const SizedBox(height: 2),
        MonthDataToken(
          color: pauseColor,
          label: formatHoursInput(details.pauseMinutes),
          textColor: textColor.withValues(alpha: 0.92),
        ),
      ],
    );
  }
}

class MonthCellTinySummary extends StatelessWidget {
  const MonthCellTinySummary({
    super.key,
    required this.day,
    required this.details,
    required this.detailColor,
    required this.workColor,
    required this.pauseColor,
  });

  final CalendarDay day;
  final CalendarDayDetails? details;
  final Color detailColor;
  final Color workColor;
  final Color pauseColor;

  @override
  Widget build(BuildContext context) {
    final hasWorkedData =
        details != null &&
        (details!.workedMinutes > 0 || details!.pauseMinutes > 0);
    final isDayOff =
        details == null && (day.primaryLabel?.startsWith('Libero') ?? false);

    return Stack(
      children: [
        if (details != null)
          Positioned.fill(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 2, bottom: 8),
                child: MonthMiniTimeline(
                  details: details!,
                  workColor: workColor,
                  pauseColor: pauseColor,
                ),
              ),
            ),
          ),
        if (hasWorkedData || isDayOff)
          Positioned(
            left: 0,
            bottom: 0,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                MonthTinyIndicator(
                  color: isDayOff
                      ? detailColor.withValues(alpha: 0.7)
                      : workColor,
                ),
                if (hasWorkedData && details!.pauseMinutes > 0) ...[
                  const SizedBox(width: 4),
                  MonthTinyIndicator(color: pauseColor),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class MonthMiniTimeline extends StatelessWidget {
  const MonthMiniTimeline({
    super.key,
    required this.details,
    required this.workColor,
    required this.pauseColor,
  });

  final CalendarDayDetails details;
  final Color workColor;
  final Color pauseColor;

  @override
  Widget build(BuildContext context) {
    final startMinutes = details.startMinutes;
    final endMinutes = details.endMinutes;
    if (startMinutes == null ||
        endMinutes == null ||
        endMinutes <= startMinutes) {
      return Container(
        width: 10,
        decoration: BoxDecoration(
          color: workColor.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(999),
        ),
      );
    }

    final pauseStartMinutes = details.pauseStartMinutes;
    final resumeMinutes = details.resumeMinutes;
    final totalMinutes = endMinutes - startMinutes;

    return SizedBox(
      width: 12,
      child: LayoutBuilder(
        builder: (context, constraints) {
          double topFor(int minutes) =>
              ((minutes - startMinutes) / totalMinutes) * constraints.maxHeight;
          double heightFor(int from, int to) =>
              math.max(6, ((to - from) / totalMinutes) * constraints.maxHeight);

          return Stack(
            children: [
              Positioned.fill(
                child: Align(
                  alignment: Alignment.center,
                  child: Container(
                    width: 6,
                    decoration: BoxDecoration(
                      color: workColor.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              ),
              if (pauseStartMinutes != null &&
                  resumeMinutes != null &&
                  resumeMinutes > pauseStartMinutes) ...[
                Positioned(
                  top: 0,
                  left: 2,
                  right: 2,
                  height: heightFor(startMinutes, pauseStartMinutes),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: workColor,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                Positioned(
                  top: topFor(pauseStartMinutes),
                  left: 2,
                  right: 2,
                  height: heightFor(pauseStartMinutes, resumeMinutes),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: pauseColor,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                Positioned(
                  top: topFor(resumeMinutes),
                  left: 2,
                  right: 2,
                  height: heightFor(resumeMinutes, endMinutes),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: workColor,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              ] else
                Positioned(
                  top: 0,
                  left: 2,
                  right: 2,
                  bottom: 0,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: workColor,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class MonthTinyIndicator extends StatelessWidget {
  const MonthTinyIndicator({super.key, required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class MonthDataToken extends StatelessWidget {
  const MonthDataToken({
    super.key,
    required this.color,
    required this.label,
    required this.textColor,
  });

  final Color color;
  final String label;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: textColor,
              fontWeight: FontWeight.w700,
              height: 1.0,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
