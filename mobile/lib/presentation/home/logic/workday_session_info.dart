// Stato e descrizioni della timbratura (sessione di lavoro) del giorno.

import 'dart:math' as math;
import 'package:work_hours_mobile/application/services/hour_input_parser.dart';
import 'package:work_hours_mobile/application/services/time_input_parser.dart';
import 'package:work_hours_mobile/application/services/workday_start_store.dart';
import 'package:work_hours_mobile/domain/models/day_schedule.dart';
import 'package:work_hours_mobile/domain/models/user_work_rules.dart';
import 'package:work_hours_mobile/presentation/home/logic/agenda_segments.dart';
import 'package:work_hours_mobile/presentation/home/logic/expected_exit.dart';
import 'package:work_hours_mobile/presentation/home/models/calendar_day.dart';

enum WorkdaySessionStatus { notStarted, active, onBreak, completed }

/// Quando si puo' uscire, partendo dall'entrata timbrata e dalla pausa fatta.
int resolveSessionExpectedExitMinutes({
  required WorkdaySession session,
  required DaySchedule schedule,
  required int nowMinutes,
}) {
  return resolveScheduleExitMinutes(
    schedule,
    startMinutes: session.startMinutes,
    actualBreakMinutes: currentSessionBreakMinutes(session, nowMinutes),
  );
}

int currentSessionBreakMinutes(WorkdaySession? session, int nowMinutes) {
  if (session == null) {
    return 0;
  }

  final runningBreakMinutes = session.breakStartedMinutes == null
      ? 0
      : math.max(0, nowMinutes - session.breakStartedMinutes!);
  return session.accumulatedBreakMinutes + runningBreakMinutes;
}

WorkdaySessionStatus resolveWorkdaySessionStatus(WorkdaySession? session) {
  if (session == null) {
    return WorkdaySessionStatus.notStarted;
  }
  if (session.isCompleted) {
    return WorkdaySessionStatus.completed;
  }
  if (session.isOnBreak) {
    return WorkdaySessionStatus.onBreak;
  }

  return WorkdaySessionStatus.active;
}

String workdaySessionDescription({
  required WorkdaySession? session,
  required DaySchedule schedule,
  required CalendarPauseWindow? pauseWindow,
  required WorkdaySessionStatus status,
  required int currentBreakMinutes,
}) {
  final displayedStart =
      parseTimeInput(schedule.startTime) ?? session?.startMinutes;
  final displayedEnd = parseTimeInput(schedule.endTime) ?? session?.endMinutes;

  return switch (status) {
    WorkdaySessionStatus.notStarted =>
      'Premi Entrata e salvo l orario attuale. Da li ti mostro subito quando puoi uscire.',
    WorkdaySessionStatus.active =>
      displayedStart == null
          ? 'Entrata registrata.'
          : 'Entrata registrata alle ${formatTimeInput(displayedStart)}.',
    WorkdaySessionStatus.onBreak =>
      'Sei in pausa dalle ${formatTimeInput(pauseWindow?.pauseStartMinutes ?? session!.breakStartedMinutes!)}. Pausa totale: ${currentBreakMinutes.toString()} min.',
    WorkdaySessionStatus.completed =>
      displayedStart == null || displayedEnd == null
          ? 'Giornata chiusa.'
          : 'Giornata chiusa. Entrata ${formatTimeInput(displayedStart)}, uscita ${formatTimeInput(displayedEnd)}.',
  };
}

String workdaySessionStatusLabel(WorkdaySessionStatus status) {
  return switch (status) {
    WorkdaySessionStatus.notStarted => 'Da iniziare',
    WorkdaySessionStatus.active => 'Dentro',
    WorkdaySessionStatus.onBreak => 'In pausa',
    WorkdaySessionStatus.completed => 'Chiusa',
  };
}

String? resolveExpectedEndInfo({
  required WorkdaySession? session,
  required DaySchedule schedule,
  required int nowMinutes,
}) {
  if (session == null || session.isCompleted || schedule.targetMinutes <= 0) {
    return null;
  }

  final explicitEndMinutes = parseTimeInput(schedule.endTime);
  if (explicitEndMinutes != null) {
    return 'Puoi uscire alle ${formatTimeInput(explicitEndMinutes)}.';
  }

  final totalMinutes = resolveSessionExpectedExitMinutes(
    session: session,
    schedule: schedule,
    nowMinutes: nowMinutes,
  );
  final exitLabel = formatExpectedExitLabel(
    totalMinutes,
    nextDaySuffix: ' del giorno dopo',
  );
  return 'Puoi uscire alle $exitLabel.';
}

String? resolveWorkedSessionInfo({
  required WorkdaySession? session,
  required DaySchedule schedule,
  required CalendarPauseWindow? pauseWindow,
  required int nowMinutes,
}) {
  // Senza timbratura non c'e' nulla di lavorato: l'orario previsto del giorno
  // non va scambiato per ore gia' fatte.
  if (session == null) {
    return null;
  }

  final measurementSegments = buildAgendaMeasurementSegments(
    schedule: schedule,
    session: session,
    nowMinutes: nowMinutes,
    pauseWindow: pauseWindow,
  );
  if (measurementSegments.isEmpty) {
    return null;
  }

  final workedMinutes = measurementSegments
      .where((segment) => segment.kind == AgendaMeasurementSegmentKind.work)
      .fold<int>(
        0,
        (total, segment) => total + (segment.endMinutes - segment.startMinutes),
      );
  final totalBreakMinutes = measurementSegments
      .where((segment) => segment.kind == AgendaMeasurementSegmentKind.pause)
      .fold<int>(
        0,
        (total, segment) => total + (segment.endMinutes - segment.startMinutes),
      );
  return 'Lavoro ${formatHoursInput(workedMinutes)} | Pausa ${formatHoursInput(totalBreakMinutes)}.';
}

/// Elenco leggibile dei segmenti pausa registrati, inclusa quella in corso.
String? formatWorkdayBreakSegments(WorkdaySession? session) {
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
