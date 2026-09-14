// Etichette e dettagli testuali delle celle del calendario.

import 'package:work_hours_mobile/application/services/hour_input_parser.dart';
import 'package:work_hours_mobile/application/services/time_input_parser.dart';
import 'package:work_hours_mobile/application/services/workday_start_store.dart';
import 'package:work_hours_mobile/domain/models/day_schedule.dart';
import 'package:work_hours_mobile/presentation/home/logic/agenda_segments.dart';
import 'package:work_hours_mobile/presentation/home/logic/workday_session_info.dart';
import 'package:work_hours_mobile/presentation/home/models/calendar_day.dart';

String? buildCalendarDayPrimaryLabel({
  required CalendarDayRelation relation,
  required DaySchedule schedule,
  required int workedMinutes,
  required int leaveMinutes,
  required bool hasOverride,
}) {
  return switch (relation) {
    CalendarDayRelation.past => buildPastCalendarDayLabel(
      workedMinutes: workedMinutes,
      leaveMinutes: leaveMinutes,
      hasOverride: hasOverride,
      schedule: schedule,
    ),
    CalendarDayRelation.today ||
    CalendarDayRelation.future => buildScheduledCalendarDayLabel(schedule),
  };
}

String? buildCalendarDaySecondaryLabel({
  required CalendarDayRelation relation,
  required int workedMinutes,
  required int leaveMinutes,
  required bool hasOverride,
  required String? todayStatusLabel,
  bool needsRegistration = false,
}) {
  return switch (relation) {
    CalendarDayRelation.past => switch ((
      workedMinutes > 0,
      leaveMinutes > 0,
      hasOverride,
    )) {
      (true, true, _) => 'Registrato + permesso',
      (true, false, _) => 'Registrato',
      (false, true, _) => 'Permesso',
      // Pesa come debito: meglio dirlo che lasciare la cella vuota.
      _ when needsRegistration => 'Da registrare',
      (false, false, true) => 'Modificato',
      _ => null,
    },
    CalendarDayRelation.today => todayStatusLabel ?? 'Oggi',
    CalendarDayRelation.future => hasOverride ? 'Personalizzato' : 'Default',
  };
}

String? buildPastCalendarDayLabel({
  required int workedMinutes,
  required int leaveMinutes,
  required bool hasOverride,
  required DaySchedule schedule,
}) {
  if (workedMinutes > 0 && leaveMinutes > 0) {
    return '${formatHoursInput(workedMinutes)} + ${formatHoursInput(leaveMinutes)}';
  }
  if (workedMinutes > 0) {
    return '${formatHoursInput(workedMinutes)} lavoro';
  }
  if (leaveMinutes > 0) {
    return '${formatHoursInput(leaveMinutes)} permesso';
  }
  if (hasOverride) {
    return buildScheduledCalendarDayLabel(schedule) ?? 'Modificato';
  }
  return null;
}

String? buildScheduledCalendarDayLabel(DaySchedule schedule) {
  final start = schedule.startTime?.trim();
  final end = schedule.endTime?.trim();
  if (start != null && start.isNotEmpty && end != null && end.isNotEmpty) {
    return '$start-$end';
  }
  if (schedule.targetMinutes > 0) {
    return formatHoursInput(schedule.targetMinutes);
  }
  return 'Libero';
}

CalendarDayDetails? buildCalendarDayDetails({
  required CalendarDayRelation relation,
  required DaySchedule schedule,
  required int workedMinutes,
  required int leaveMinutes,
  required WorkdaySession? session,
}) {
  final startMinutes =
      session?.startMinutes ?? parseTimeInput(schedule.startTime);
  final explicitEndMinutes = parseTimeInput(schedule.endTime);
  final nowMinutes = (DateTime.now().hour * 60) + DateTime.now().minute;
  final endMinutes = session?.endMinutes ?? explicitEndMinutes;
  final hasRegisteredWorkOrLeave = workedMinutes > 0 || leaveMinutes > 0;
  // Un giorno passato conta solo cio' che e' registrato: l'orario del piano
  // resta disegnato, ma non vale come ore ne' come pausa fatte.
  final isUnregisteredPast =
      relation == CalendarDayRelation.past && !hasRegisteredWorkOrLeave;
  final pauseMinutes = session != null
      ? currentSessionBreakMinutes(session, nowMinutes)
      : isUnregisteredPast
      ? 0
      : schedule.breakMinutes;
  final resolvedWorkedMinutes = session != null
      ? resolveSessionWorkedMinutes(session: session, nowMinutes: nowMinutes)
      : relation == CalendarDayRelation.past
      ? workedMinutes
      : 0;

  if (startMinutes == null &&
      endMinutes == null &&
      resolvedWorkedMinutes == 0 &&
      pauseMinutes == 0 &&
      leaveMinutes == 0) {
    return null;
  }

  final timelineLines = <String>[];
  if (startMinutes != null) {
    timelineLines.add('Inizio: ${formatTimeInput(startMinutes)}');
  }

  final pauseWindow = resolveCalendarPauseWindow(
    schedule: schedule,
    startMinutes: startMinutes,
    endMinutes: endMinutes,
    session: session,
    nowMinutes: nowMinutes,
  );
  if (pauseWindow != null) {
    timelineLines.add(
      'Pausa: ${formatTimeInput(pauseWindow.pauseStartMinutes)}',
    );
    timelineLines.add('Ripresa: ${formatTimeInput(pauseWindow.resumeMinutes)}');
  }

  if (endMinutes != null) {
    timelineLines.add('Fine: ${formatTimeInput(endMinutes)}');
  }

  return CalendarDayDetails(
    timelineLines: timelineLines,
    workedLabel: 'Lavorato: ${formatHoursInput(resolvedWorkedMinutes)}',
    pauseLabel: 'Pausa: ${formatHoursInput(pauseMinutes)}',
    workedMinutes: resolvedWorkedMinutes,
    pauseMinutes: pauseMinutes,
    startMinutes: startMinutes,
    pauseStartMinutes: pauseWindow?.pauseStartMinutes,
    resumeMinutes: pauseWindow?.resumeMinutes,
    endMinutes: endMinutes,
  );
}
