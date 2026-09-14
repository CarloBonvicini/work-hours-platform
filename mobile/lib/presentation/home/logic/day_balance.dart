// Calcolo di ore attese, lavorate (anche live) e uscita suggerita per un giorno.

import 'dart:math' as math;
import 'package:work_hours_mobile/application/services/time_input_parser.dart';
import 'package:work_hours_mobile/application/services/workday_start_store.dart';
import 'package:work_hours_mobile/domain/models/day_schedule.dart';
import 'package:work_hours_mobile/domain/models/user_work_rules.dart';
import 'package:work_hours_mobile/presentation/home/logic/agenda_segments.dart';
import 'package:work_hours_mobile/presentation/home/models/calendar_day.dart';

bool matchesDaySchedule(DaySchedule left, DaySchedule right) {
  return left.targetMinutes == right.targetMinutes &&
      left.startTime == right.startTime &&
      left.endTime == right.endTime &&
      left.breakMinutes == right.breakMinutes;
}

bool isExplicitDayOffSchedule(DaySchedule schedule) {
  final startTime = schedule.startTime?.trim() ?? '';
  final endTime = schedule.endTime?.trim() ?? '';
  return schedule.targetMinutes == 0 &&
      schedule.breakMinutes == 0 &&
      startTime.isEmpty &&
      endTime.isEmpty;
}

int resolveDisplayedExpectedMinutes({
  required DaySchedule effectiveSchedule,
  required DaySchedule quickEditorSchedule,
}) {
  if (isExplicitDayOffSchedule(quickEditorSchedule)) {
    return 0;
  }

  return effectiveSchedule.targetMinutes;
}

int? resolveComputedWorkedMinutes({
  required DaySchedule schedule,
  int minimumBreakMinutes = 0,
}) {
  final startMinutes = parseTimeInput(schedule.startTime);
  final endMinutes = parseTimeInput(schedule.endTime);
  if (startMinutes == null ||
      endMinutes == null ||
      endMinutes <= startMinutes) {
    return null;
  }

  final effectiveBreakMinutes = math.max(
    schedule.breakMinutes,
    minimumBreakMinutes,
  );
  return math.max(0, endMinutes - startMinutes - effectiveBreakMinutes);
}

int resolveDisplayedWorkedMinutes({
  required DaySchedule quickEditorSchedule,
  required UserWorkRules workRules,
}) {
  return resolveComputedWorkedMinutes(
        schedule: quickEditorSchedule,
        minimumBreakMinutes: workRules.minimumBreakMinutes,
      ) ??
      0;
}

int resolveLiveWorkedMinutes({
  required DaySchedule quickEditorSchedule,
  required UserWorkRules workRules,
  required WorkdaySession? session,
  required CalendarPauseWindow? pauseWindow,
  required int nowMinutes,
  String? rawStartTimeText,
  String? rawEndTimeText,
  bool treatEndAsActual = false,
}) {
  if (session != null) {
    // Solo i segmenti della sessione: entrata timbrata e pause registrate.
    // Passare per l'agenda faceva vincere la finestra del piano, e l'uscita
    // prevista finiva contata come ora gia' lavorata.
    final measurementSegments = buildSessionMeasurementSegments(
      session: session,
      nowMinutes: nowMinutes,
    );
    if (measurementSegments.isNotEmpty) {
      return measurementSegments
          .where((segment) => segment.kind == AgendaMeasurementSegmentKind.work)
          .fold<int>(
            0,
            (total, segment) =>
                total + (segment.endMinutes - segment.startMinutes),
          );
    }
  }

  final resolvedStartMinutes =
      parseTimeInput(rawStartTimeText?.trim()) ??
      parseTimeInput(quickEditorSchedule.startTime);
  final resolvedEndMinutes =
      parseTimeInput(rawEndTimeText?.trim()) ??
      parseTimeInput(quickEditorSchedule.endTime);

  if (resolvedStartMinutes == null) {
    return resolveDisplayedWorkedMinutes(
      quickEditorSchedule: quickEditorSchedule,
      workRules: workRules,
    );
  }

  if (treatEndAsActual &&
      resolvedEndMinutes != null &&
      resolvedEndMinutes > resolvedStartMinutes &&
      resolvedEndMinutes <= nowMinutes) {
    final breakMinutes = quickEditorSchedule.breakMinutes.clamp(
      0,
      resolvedEndMinutes - resolvedStartMinutes,
    );
    return math.max(
      0,
      resolvedEndMinutes - resolvedStartMinutes - breakMinutes,
    );
  }

  // For today we keep the worked counter aligned with the current clock time.
  // The planned/scheduled end time does not freeze the live counter.
  final runningMinutes = math.max(0, nowMinutes - resolvedStartMinutes);
  return math.max(0, runningMinutes - quickEditorSchedule.breakMinutes);
}

int? resolveSuggestedExitTotalMinutes({
  required DaySchedule effectiveSchedule,
  required DaySchedule quickEditorSchedule,
  required UserWorkRules workRules,
  String? rawStartTimeText,
}) {
  final expectedMinutes = resolveDisplayedExpectedMinutes(
    effectiveSchedule: effectiveSchedule,
    quickEditorSchedule: quickEditorSchedule,
  );
  if (expectedMinutes <= 0) {
    return null;
  }

  final startMinutes =
      parseTimeInput(rawStartTimeText?.trim()) ??
      parseTimeInput(quickEditorSchedule.startTime) ??
      parseTimeInput(effectiveSchedule.startTime);
  if (startMinutes == null) {
    return null;
  }

  final effectiveBreakMinutes = math.max(
    quickEditorSchedule.breakMinutes,
    math.max(effectiveSchedule.breakMinutes, workRules.minimumBreakMinutes),
  );
  return startMinutes + expectedMinutes + effectiveBreakMinutes;
}

String resolveSuggestedExitLabel({
  required DaySchedule effectiveSchedule,
  required DaySchedule quickEditorSchedule,
  required UserWorkRules workRules,
  String? rawStartTimeText,
  String? rawEndTimeText,
}) {
  final expectedMinutes = resolveDisplayedExpectedMinutes(
    effectiveSchedule: effectiveSchedule,
    quickEditorSchedule: quickEditorSchedule,
  );
  if (expectedMinutes <= 0) {
    return 'Libero';
  }

  final suggestedExitTotalMinutes = resolveSuggestedExitTotalMinutes(
    effectiveSchedule: effectiveSchedule,
    quickEditorSchedule: quickEditorSchedule,
    workRules: workRules,
    rawStartTimeText: rawStartTimeText,
  );
  if (suggestedExitTotalMinutes == null) {
    final fallbackEndMinutes =
        parseTimeInput(rawEndTimeText?.trim()) ??
        parseTimeInput(effectiveSchedule.endTime) ??
        parseTimeInput(quickEditorSchedule.endTime);
    return fallbackEndMinutes == null
        ? '--:--'
        : formatTimeInput(fallbackEndMinutes);
  }

  final normalizedMinutes = suggestedExitTotalMinutes % (24 * 60);
  final nextDaySuffix = suggestedExitTotalMinutes >= (24 * 60) ? ' +1g' : '';
  return '${formatTimeInput(normalizedMinutes)}$nextDaySuffix';
}
