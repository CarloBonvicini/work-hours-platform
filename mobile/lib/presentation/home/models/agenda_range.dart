// Intervallo orario visualizzato dall'agenda e regole per calcolarlo.

import 'dart:math' as math;
import 'package:work_hours_mobile/application/services/time_input_parser.dart';
import 'package:work_hours_mobile/domain/models/day_schedule.dart';
import 'package:work_hours_mobile/presentation/home/models/day_metrics.dart';

class AgendaRange {
  const AgendaRange({required this.startMinutes, required this.endMinutes});

  final int startMinutes;
  final int endMinutes;

  int get totalMinutes => endMinutes - startMinutes;

  Iterable<int> get hourMarks sync* {
    for (var mark = startMinutes; mark <= endMinutes; mark += 60) {
      yield mark;
    }
  }

  double timelineHeight({double pixelsPerHour = 32, double minHeight = 280}) {
    final computedHeight = (totalMinutes / 60) * pixelsPerHour;
    return math.max(computedHeight, minHeight).toDouble();
  }

  double positionFor(int minutes, double height) {
    if (totalMinutes <= 0) {
      return 0;
    }

    final clampedMinutes = minutes.clamp(startMinutes, endMinutes).toDouble();
    return ((clampedMinutes - startMinutes) / totalMinutes) * height;
  }

  int minutesForPosition(double position, double height, {int snapStep = 1}) {
    if (height <= 0 || totalMinutes <= 0) {
      return startMinutes;
    }

    final ratio = (position / height).clamp(0.0, 1.0);
    final rawMinutes = startMinutes + (ratio * totalMinutes);
    final snappedMinutes = ((rawMinutes / snapStep).round() * snapStep).toInt();
    return snappedMinutes.clamp(startMinutes, endMinutes);
  }
}

AgendaRange resolveAgendaRange(Iterable<DayMetrics> metricsCollection) {
  return resolveAgendaRangeForSchedules(
    metricsCollection.map((metrics) => metrics.schedule),
  );
}

AgendaRange resolveCompactAgendaRangeForBounds({
  required int? startMinutes,
  required int? endMinutes,
}) {
  if (startMinutes == null ||
      endMinutes == null ||
      endMinutes <= startMinutes) {
    return const AgendaRange(startMinutes: 6 * 60, endMinutes: 22 * 60);
  }

  var stableStartMinutes = math.max(0, startMinutes - 30);
  var stableEndMinutes = math.min((23 * 60) + 59, endMinutes + 45);
  stableStartMinutes = (stableStartMinutes ~/ 60) * 60;
  stableEndMinutes = ((stableEndMinutes + 59) ~/ 60) * 60;
  stableEndMinutes = math.min(stableEndMinutes, (23 * 60) + 59);

  if ((stableEndMinutes - stableStartMinutes) < 8 * 60) {
    final midpoint = (startMinutes + endMinutes) ~/ 2;
    stableStartMinutes = (midpoint - (8 * 60 ~/ 2)).clamp(0, 16 * 60).toInt();
    stableStartMinutes = (stableStartMinutes ~/ 60) * 60;
    stableEndMinutes = math.min(stableStartMinutes + 8 * 60, (23 * 60) + 59);
  }

  if (stableEndMinutes <= stableStartMinutes) {
    return const AgendaRange(startMinutes: 6 * 60, endMinutes: 22 * 60);
  }

  return AgendaRange(
    startMinutes: stableStartMinutes,
    endMinutes: stableEndMinutes,
  );
}

AgendaRange resolveAgendaRangeForSchedules(Iterable<DaySchedule> schedules) {
  final starts = <int>[];
  final ends = <int>[];

  for (final schedule in schedules) {
    final startMinutes = parseTimeInput(schedule.startTime);
    final endMinutes = parseTimeInput(schedule.endTime);
    if (startMinutes == null ||
        endMinutes == null ||
        endMinutes <= startMinutes) {
      continue;
    }
    starts.add(startMinutes);
    ends.add(endMinutes);
  }

  if (starts.isEmpty || ends.isEmpty) {
    return const AgendaRange(startMinutes: 6 * 60, endMinutes: 22 * 60);
  }
  return resolveCompactAgendaRangeForBounds(
    startMinutes: starts.reduce(math.min),
    endMinutes: ends.reduce(math.max),
  );
}

double resolveAgendaLabelTop(double position, double height) {
  const labelHeight = 18.0;
  return math.min(
    math.max(position - (labelHeight / 2), 0),
    height - labelHeight,
  );
}
