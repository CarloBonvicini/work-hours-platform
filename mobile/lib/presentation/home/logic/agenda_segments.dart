// Segmenti di misura (lavoro/pausa) della giornata usati da agenda e riepiloghi.

import 'dart:math' as math;
import 'package:work_hours_mobile/application/services/hour_input_parser.dart';
import 'package:work_hours_mobile/application/services/time_input_parser.dart';
import 'package:work_hours_mobile/application/services/workday_start_store.dart';
import 'package:work_hours_mobile/domain/models/day_schedule.dart';
import 'package:work_hours_mobile/presentation/home/logic/hours_labels.dart';
import 'package:work_hours_mobile/presentation/home/models/calendar_day.dart';

enum AgendaMeasurementSegmentKind { work, pause }

class AgendaMeasurementSegment {
  const AgendaMeasurementSegment({
    required this.startMinutes,
    required this.endMinutes,
    required this.label,
    required this.kind,
  });

  final int startMinutes;
  final int endMinutes;
  final String label;
  final AgendaMeasurementSegmentKind kind;
}

List<AgendaMeasurementSegment> resolveEffectiveAgendaSegments({
  required int startMinutes,
  required int endMinutes,
  required List<AgendaMeasurementSegment> measurementSegments,
}) {
  if (measurementSegments.isEmpty) {
    return [
      AgendaMeasurementSegment(
        startMinutes: startMinutes,
        endMinutes: endMinutes,
        label: '',
        kind: AgendaMeasurementSegmentKind.work,
      ),
    ];
  }

  return [
    for (final segment in measurementSegments)
      if (segment.endMinutes > startMinutes &&
          segment.startMinutes < endMinutes)
        AgendaMeasurementSegment(
          startMinutes: math.max(segment.startMinutes, startMinutes),
          endMinutes: math.min(segment.endMinutes, endMinutes),
          label: segment.label,
          kind: segment.kind,
        ),
  ];
}

CalendarPauseWindow? resolveCalendarPauseWindow({
  required DaySchedule schedule,
  required int? startMinutes,
  required int? endMinutes,
  required WorkdaySession? session,
  required int nowMinutes,
}) {
  if (session != null) {
    final orderedBreakSegments = [...session.breakSegments]
      ..sort((left, right) => left.startMinutes.compareTo(right.startMinutes));
    if (orderedBreakSegments.isNotEmpty) {
      final firstBreak = orderedBreakSegments.first;
      return CalendarPauseWindow(
        pauseStartMinutes: firstBreak.startMinutes,
        resumeMinutes: firstBreak.endMinutes,
      );
    }
    if (session.breakStartedMinutes != null) {
      final pauseEndMinutes = session.endMinutes ?? nowMinutes;
      if (pauseEndMinutes > session.breakStartedMinutes!) {
        return CalendarPauseWindow(
          pauseStartMinutes: session.breakStartedMinutes!,
          resumeMinutes: pauseEndMinutes,
        );
      }
    }
  }

  if (schedule.breakMinutes <= 0 ||
      startMinutes == null ||
      endMinutes == null) {
    return null;
  }

  final totalPresenceMinutes = endMinutes - startMinutes;
  if (totalPresenceMinutes <= schedule.breakMinutes) {
    return null;
  }

  final workMinutes = totalPresenceMinutes - schedule.breakMinutes;
  final pauseStartMinutes = startMinutes + (workMinutes ~/ 2);
  final resumeMinutes = pauseStartMinutes + schedule.breakMinutes;
  if (resumeMinutes > endMinutes) {
    return null;
  }

  return CalendarPauseWindow(
    pauseStartMinutes: pauseStartMinutes,
    resumeMinutes: resumeMinutes,
  );
}

List<AgendaMeasurementSegment> buildAgendaMeasurementSegments({
  required DaySchedule schedule,
  required WorkdaySession? session,
  required int nowMinutes,
  CalendarPauseWindow? pauseWindow,
}) {
  final startMinutes = parseTimeInput(schedule.startTime);
  final endMinutes = parseTimeInput(schedule.endTime);
  if (pauseWindow != null &&
      startMinutes != null &&
      endMinutes != null &&
      endMinutes > startMinutes) {
    final segments = <AgendaMeasurementSegment>[];
    if (pauseWindow.pauseStartMinutes > startMinutes) {
      segments.add(
        AgendaMeasurementSegment(
          startMinutes: startMinutes,
          endMinutes: pauseWindow.pauseStartMinutes,
          label:
              '${formatHoursInput(pauseWindow.pauseStartMinutes - startMinutes)} lavoro',
          kind: AgendaMeasurementSegmentKind.work,
        ),
      );
    }
    if (pauseWindow.resumeMinutes > pauseWindow.pauseStartMinutes) {
      segments.add(
        AgendaMeasurementSegment(
          startMinutes: pauseWindow.pauseStartMinutes,
          endMinutes: pauseWindow.resumeMinutes,
          label:
              '${formatHoursInput(pauseWindow.resumeMinutes - pauseWindow.pauseStartMinutes)} pausa',
          kind: AgendaMeasurementSegmentKind.pause,
        ),
      );
    }
    if (pauseWindow.resumeMinutes < endMinutes) {
      segments.add(
        AgendaMeasurementSegment(
          startMinutes: pauseWindow.resumeMinutes,
          endMinutes: endMinutes,
          label:
              '${formatHoursInput(endMinutes - pauseWindow.resumeMinutes)} lavoro',
          kind: AgendaMeasurementSegmentKind.work,
        ),
      );
    }
    if (segments.isNotEmpty) {
      return segments;
    }
  }

  if (session == null) {
    if (schedule.targetMinutes <= 0 ||
        startMinutes == null ||
        endMinutes == null ||
        endMinutes <= startMinutes) {
      return const [];
    }
    final pauseWindow = resolveCalendarPauseWindow(
      schedule: schedule,
      startMinutes: startMinutes,
      endMinutes: endMinutes,
      session: null,
      nowMinutes: nowMinutes,
    );
    if (pauseWindow == null) {
      return [
        AgendaMeasurementSegment(
          startMinutes: startMinutes,
          endMinutes: endMinutes,
          label: '${formatHours(schedule.targetMinutes)} lavoro',
          kind: AgendaMeasurementSegmentKind.work,
        ),
      ];
    }

    final segments = <AgendaMeasurementSegment>[];
    if (pauseWindow.pauseStartMinutes > startMinutes) {
      segments.add(
        AgendaMeasurementSegment(
          startMinutes: startMinutes,
          endMinutes: pauseWindow.pauseStartMinutes,
          label:
              '${formatHoursInput(pauseWindow.pauseStartMinutes - startMinutes)} lavoro',
          kind: AgendaMeasurementSegmentKind.work,
        ),
      );
    }
    segments.add(
      AgendaMeasurementSegment(
        startMinutes: pauseWindow.pauseStartMinutes,
        endMinutes: pauseWindow.resumeMinutes,
        label:
            '${formatHoursInput(pauseWindow.resumeMinutes - pauseWindow.pauseStartMinutes)} pausa',
        kind: AgendaMeasurementSegmentKind.pause,
      ),
    );
    if (pauseWindow.resumeMinutes < endMinutes) {
      segments.add(
        AgendaMeasurementSegment(
          startMinutes: pauseWindow.resumeMinutes,
          endMinutes: endMinutes,
          label:
              '${formatHoursInput(endMinutes - pauseWindow.resumeMinutes)} lavoro',
          kind: AgendaMeasurementSegmentKind.work,
        ),
      );
    }
    return segments;
  }

  return buildSessionMeasurementSegments(
    session: session,
    nowMinutes: nowMinutes,
  );
}

/// Segmenti di cio' che e' davvero successo: entrata timbrata e pause registrate.
///
/// Non guarda mai l'orario del piano. L'uscita prevista e' una previsione, non un
/// fatto: se entrasse qui, alle 12:49 risulterebbero gia' lavorate le ore di
/// tutta la giornata.
List<AgendaMeasurementSegment> buildSessionMeasurementSegments({
  required WorkdaySession session,
  required int nowMinutes,
}) {
  final segments = <AgendaMeasurementSegment>[];
  final resolvedEndMinutes = session.endMinutes ?? nowMinutes;
  final breakSegments = [...session.breakSegments]
    ..sort((left, right) => left.startMinutes.compareTo(right.startMinutes));

  var cursor = session.startMinutes;
  for (final breakSegment in breakSegments) {
    if (breakSegment.startMinutes > cursor) {
      final workMinutes = breakSegment.startMinutes - cursor;
      if (workMinutes > 0) {
        segments.add(
          AgendaMeasurementSegment(
            startMinutes: cursor,
            endMinutes: breakSegment.startMinutes,
            label: '${formatHoursInput(workMinutes)} lavoro',
            kind: AgendaMeasurementSegmentKind.work,
          ),
        );
      }
    }

    final pauseMinutes = breakSegment.endMinutes - breakSegment.startMinutes;
    if (pauseMinutes > 0) {
      segments.add(
        AgendaMeasurementSegment(
          startMinutes: breakSegment.startMinutes,
          endMinutes: breakSegment.endMinutes,
          label: '${formatHoursInput(pauseMinutes)} pausa',
          kind: AgendaMeasurementSegmentKind.pause,
        ),
      );
    }
    cursor = math.max(cursor, breakSegment.endMinutes);
  }

  if (session.breakStartedMinutes != null &&
      resolvedEndMinutes > session.breakStartedMinutes!) {
    if (session.breakStartedMinutes! > cursor) {
      final workMinutes = session.breakStartedMinutes! - cursor;
      if (workMinutes > 0) {
        segments.add(
          AgendaMeasurementSegment(
            startMinutes: cursor,
            endMinutes: session.breakStartedMinutes!,
            label: '${formatHoursInput(workMinutes)} lavoro',
            kind: AgendaMeasurementSegmentKind.work,
          ),
        );
      }
    }

    final activePauseMinutes =
        resolvedEndMinutes - session.breakStartedMinutes!;
    if (activePauseMinutes > 0) {
      segments.add(
        AgendaMeasurementSegment(
          startMinutes: session.breakStartedMinutes!,
          endMinutes: resolvedEndMinutes,
          label: '${formatHoursInput(activePauseMinutes)} pausa',
          kind: AgendaMeasurementSegmentKind.pause,
        ),
      );
    }
    return segments;
  }

  if (resolvedEndMinutes > cursor) {
    final workMinutes = resolvedEndMinutes - cursor;
    if (workMinutes > 0) {
      segments.add(
        AgendaMeasurementSegment(
          startMinutes: cursor,
          endMinutes: resolvedEndMinutes,
          label: '${formatHoursInput(workMinutes)} lavoro',
          kind: AgendaMeasurementSegmentKind.work,
        ),
      );
    }
  }

  return segments;
}

/// Minuti di un tipo (lavoro o pausa) sommati sui segmenti.
int sumSegmentMinutes(
  List<AgendaMeasurementSegment> segments,
  AgendaMeasurementSegmentKind kind,
) {
  return segments
      .where((segment) => segment.kind == kind)
      .fold<int>(
        0,
        (total, segment) => total + (segment.endMinutes - segment.startMinutes),
      );
}

/// Ore gia' lavorate secondo la timbratura: l'unico conto delle ore di oggi.
int resolveSessionWorkedMinutes({
  required WorkdaySession session,
  required int nowMinutes,
}) {
  return sumSegmentMinutes(
    buildSessionMeasurementSegments(session: session, nowMinutes: nowMinutes),
    AgendaMeasurementSegmentKind.work,
  );
}

/// Riga di totale sotto l'agenda.
///
/// Con [isForecast] i segmenti sono il piano, non ore fatte: la riga lo dice,
/// invece di chiamarle "lavorate".
String? buildAgendaWorkedSummary({
  required List<AgendaMeasurementSegment> measurementSegments,
  bool isForecast = false,
}) {
  if (measurementSegments.isEmpty) {
    return null;
  }

  final workedLabel = formatHoursInput(
    sumSegmentMinutes(measurementSegments, AgendaMeasurementSegmentKind.work),
  );
  final pauseLabel = formatHoursInput(
    sumSegmentMinutes(measurementSegments, AgendaMeasurementSegmentKind.pause),
  );

  return isForecast
      ? 'Previsto: $workedLabel lavoro | $pauseLabel pausa'
      : 'Totale: $workedLabel lavorate | $pauseLabel pausa';
}
