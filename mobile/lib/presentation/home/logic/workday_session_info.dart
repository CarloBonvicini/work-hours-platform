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

/// Orario di oggi come si mostra con la timbratura in corso.
///
/// L'entrata e' quella timbrata, salvo un'entrata scritta a mano. L'uscita
/// scritta a mano resta com'e'; altrimenti parte dall'entrata che contano le
/// regole ([resolveExitAnchorStartMinutes]) con la formula della modifica
/// rapida, pausa minima compresa. Prima lo stato ne teneva una copia che
/// ignorava pausa minima e regole d'entrata: entrando alle 08:15 con un piano
/// 08:00-17:00 l'uscita restava alle 17:00 anche senza orario fisso.
DaySchedule resolveDisplayedSessionSchedule({
  required DaySchedule schedule,
  required DaySchedule baseSchedule,
  required WorkdaySession session,
  required int nowMinutes,
  UserWorkRules? workRules,
}) {
  final explicitStartMinutes = parseTimeInput(schedule.startTime);
  final explicitEndMinutes = parseTimeInput(schedule.endTime);
  final baseStartMinutes = parseTimeInput(baseSchedule.startTime);
  final baseEndMinutes = parseTimeInput(baseSchedule.endTime);
  final currentBreakMinutes = currentSessionBreakMinutes(session, nowMinutes);
  final usesDefaultStart =
      explicitStartMinutes == null ||
      (baseStartMinutes != null && explicitStartMinutes == baseStartMinutes);
  final usesDefaultEnd =
      explicitEndMinutes == null ||
      (baseEndMinutes != null && explicitEndMinutes == baseEndMinutes);
  final displayedStartMinutes = usesDefaultStart
      ? session.startMinutes
      : explicitStartMinutes;
  final endMinutes = _resolveSessionEndMinutes(
    session: session,
    schedule: schedule,
    displayedStartMinutes: displayedStartMinutes,
    plannedStartMinutes: baseStartMinutes,
    explicitEndMinutes: explicitEndMinutes,
    usesDefaultEnd: usesDefaultEnd,
    currentBreakMinutes: currentBreakMinutes,
    workRules: workRules,
  );

  return DaySchedule(
    // L'obiettivo resta quello del giorno: spostare entrata e uscita non
    // riscrive le ore da fare.
    targetMinutes: schedule.targetMinutes,
    startTime: formatTimeInput(displayedStartMinutes),
    endTime: endMinutes == null
        ? schedule.endTime
        : formatTimeInput(clampExitToDayEnd(endMinutes)),
    breakMinutes: math.max(schedule.breakMinutes, currentBreakMinutes),
  );
}

int? _resolveSessionEndMinutes({
  required WorkdaySession session,
  required DaySchedule schedule,
  required int displayedStartMinutes,
  required int? plannedStartMinutes,
  required int? explicitEndMinutes,
  required bool usesDefaultEnd,
  required int currentBreakMinutes,
  required UserWorkRules? workRules,
}) {
  if (session.endMinutes != null && usesDefaultEnd) {
    return session.endMinutes;
  }
  // Uscita scritta a mano, o giornata senza ore da fare: resta com'e'.
  if (!usesDefaultEnd || schedule.targetMinutes <= 0) {
    return explicitEndMinutes;
  }
  // Orario fisso senza flessibilita': si esce all'ora del piano.
  if (explicitEndMinutes != null &&
      workRules != null &&
      workRules.fixedScheduleEnabled &&
      resolveFlexibleStartWindowMinutes(workRules) == 0) {
    return explicitEndMinutes;
  }

  return resolveScheduleExitMinutes(
    schedule,
    startMinutes: resolveExitAnchorStartMinutes(
      actualStartMinutes: displayedStartMinutes,
      plannedStartMinutes: plannedStartMinutes,
      workRules: workRules,
    ),
    actualBreakMinutes: currentBreakMinutes,
    minimumBreakMinutes: workRules?.minimumBreakMinutes ?? 0,
  );
}

/// Cosa l'uscita scrive nel giorno: ore da registrare e pausa scalata.
class SessionRegistration {
  const SessionRegistration({
    required this.workedMinutes,
    required this.breakMinutes,
  });

  final int workedMinutes;
  final int breakMinutes;
}

/// Ore e pausa che l'uscita registra per una timbratura chiusa.
///
/// Le ore non sono lo stesso numero del contatore dal vivo
/// (`resolveSessionWorkedMinutes` in `agenda_segments.dart`): quello misura solo
/// le pause davvero timbrate, questo scala anche la pausa prevista del giorno.
/// Chi salta la pausa vede il contatore salire e poi si ritrova registrate meno
/// ore.
SessionRegistration resolveSessionRegistration({
  required WorkdaySession session,
  required DaySchedule schedule,
}) {
  final breakMinutes = math.max(
    schedule.breakMinutes,
    session.accumulatedBreakMinutes,
  );
  final endMinutes = session.endMinutes;
  return SessionRegistration(
    workedMinutes: endMinutes == null
        ? 0
        : endMinutes - session.startMinutes - breakMinutes,
    breakMinutes: breakMinutes,
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
  required int nowMinutes,
}) {
  // Senza timbratura non c'e' nulla di lavorato: l'orario previsto del giorno
  // non va scambiato per ore gia' fatte.
  if (session == null) {
    return null;
  }

  // Solo la sessione: con l'orario del giorno la misura arrivava fino
  // all'uscita prevista, e alle 12:49 risultavano 8:00 lavorate.
  final measurementSegments = buildSessionMeasurementSegments(
    session: session,
    nowMinutes: nowMinutes,
  );
  if (measurementSegments.isEmpty) {
    return null;
  }

  final workedMinutes = sumSegmentMinutes(
    measurementSegments,
    AgendaMeasurementSegmentKind.work,
  );
  final totalBreakMinutes = sumSegmentMinutes(
    measurementSegments,
    AgendaMeasurementSegmentKind.pause,
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
