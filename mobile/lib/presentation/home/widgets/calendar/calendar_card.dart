// Card principale del calendario: viste giorno/settimana/mese/anno, editor rapido e timbratura.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:work_hours_mobile/application/services/hour_input_parser.dart';
import 'package:work_hours_mobile/application/services/theme_preference_store.dart';
import 'package:work_hours_mobile/application/services/workday_start_store.dart';
import 'package:work_hours_mobile/domain/models/day_schedule.dart';
import 'package:work_hours_mobile/presentation/home/models/activity_item.dart';
import 'package:work_hours_mobile/domain/models/user_work_rules.dart';
import 'package:work_hours_mobile/presentation/home/logic/calendar_dates.dart';
import 'package:work_hours_mobile/presentation/home/logic/day_balance.dart';
import 'package:work_hours_mobile/presentation/home/logic/day_exit_view.dart';
import 'package:work_hours_mobile/presentation/home/logic/day_worked_view.dart';
import 'package:work_hours_mobile/presentation/home/models/home_section.dart';
import 'package:work_hours_mobile/presentation/home/logic/quick_day_insights.dart';
import 'package:work_hours_mobile/presentation/home/logic/quick_day_summary_label.dart';
import 'package:work_hours_mobile/presentation/home/logic/workday_session_info.dart';
import 'package:work_hours_mobile/presentation/home/models/calendar_day.dart';
import 'package:work_hours_mobile/presentation/home/models/calendar_view.dart';
import 'package:work_hours_mobile/presentation/home/models/day_metrics.dart';
import 'package:work_hours_mobile/presentation/home/widgets/calendar/calendar_period_summary.dart';
import 'package:work_hours_mobile/presentation/home/widgets/calendar/calendar_period_switcher.dart';
import 'package:work_hours_mobile/presentation/home/widgets/calendar/calendar_quick_schedule_editor.dart';
import 'package:work_hours_mobile/presentation/home/widgets/calendar/workday_session_card.dart';
import 'package:work_hours_mobile/presentation/home/widgets/shared/section_cards.dart';

class CalendarCard extends StatelessWidget {
  const CalendarCard({
    super.key,
    required this.title,
    required this.showViewSelector,
    required this.calendarView,
    required this.periodLabel,
    required this.isLoadingCalendarData,
    required this.month,
    required this.selectedDate,
    required this.workRules,
    required this.days,
    required this.baseDaySchedule,
    required this.plannedDaySchedule,
    required this.effectiveDaySchedule,
    required this.draftDaySchedule,
    required this.quickEditorDaySchedule,
    required this.quickEditorPauseWindow,
    required this.selectedDayPauseWindow,
    required this.overrideFormKey,
    required this.appearanceSettings,
    required this.overrideTargetController,
    required this.overrideStartTimeController,
    required this.overrideEndTimeController,
    required this.overrideBreakController,
    required this.pendingExitConfirmationMinutes,
    required this.dayMetrics,
    required this.weekMetrics,
    required this.monthMetrics,
    required this.yearMetrics,
    required this.onCalendarViewChanged,
    required this.onPreviousPeriod,
    required this.onNextPeriod,
    required this.onSelectDate,
    required this.onOpenDay,
    required this.isSelectedDateToday,
    required this.dayActivities,
    required this.onOpenWorkQuickEntry,
    required this.onOpenLeaveQuickEntry,
    required this.onEditActivity,
    required this.onDeleteActivity,
    required this.workdaySession,
    required this.isSavingWorkdaySession,
    required this.onRecordWorkdayStartNow,
    required this.onStartWorkdayBreakNow,
    required this.onResumeWorkdayNow,
    required this.onFinishWorkdayNow,
    required this.onClearWorkdaySession,
    required this.onPickOverrideTargetMinutes,
    required this.onPickOverrideTime,
    required this.onPickOverrideBreakMinutes,
    required this.onAgendaSchedulePreviewChanged,
    required this.onAgendaSchedulePreviewCleared,
    required this.onAgendaScheduleChanged,
    required this.onAgendaInteractionChanged,
    required this.onAppearanceSettingsChanged,
    required this.canUndoOverrideChanges,
    required this.canRedoOverrideChanges,
    required this.onUndoOverrideChange,
    required this.onRedoOverrideChange,
    required this.onMarkDayAsOff,
    required this.onRegisterUnrecordedHours,
    required this.onOpenSettingsSection,
    required this.onRestoreWorkingDay,
    required this.onConfirmSuggestedExitMinutes,
    required this.onOpenWorkSettings,
    required this.onOvertimeLimitExceeded,
  });

  final String title;
  final bool showViewSelector;
  final CalendarView calendarView;
  final String periodLabel;
  final bool isLoadingCalendarData;
  final String month;
  final DateTime selectedDate;
  final UserWorkRules workRules;
  final List<CalendarDay> days;
  final DaySchedule baseDaySchedule;

  /// Orario previsto del giorno, completo di entrata e uscita.
  ///
  /// Riempie i campi della modifica rapida quando non c'e' ancora nulla di
  /// registrato: resta una previsione e non entra nei calcoli.
  final DaySchedule plannedDaySchedule;
  final DaySchedule effectiveDaySchedule;
  final DaySchedule draftDaySchedule;
  final DaySchedule quickEditorDaySchedule;
  final CalendarPauseWindow? quickEditorPauseWindow;
  final CalendarPauseWindow? selectedDayPauseWindow;
  final GlobalKey<FormState> overrideFormKey;
  final AppAppearanceSettings appearanceSettings;
  final TextEditingController overrideTargetController;
  final TextEditingController overrideStartTimeController;
  final TextEditingController overrideEndTimeController;
  final TextEditingController overrideBreakController;
  final int? pendingExitConfirmationMinutes;
  final DayMetrics dayMetrics;
  final List<DayMetrics> weekMetrics;
  final MonthMetrics monthMetrics;
  final List<MonthMetrics> yearMetrics;
  final Future<void> Function(CalendarView view) onCalendarViewChanged;
  final Future<void> Function() onPreviousPeriod;
  final Future<void> Function() onNextPeriod;
  final ValueChanged<DateTime> onSelectDate;
  final Future<void> Function(DateTime date) onOpenDay;
  final bool isSelectedDateToday;
  final List<ActivityItem> dayActivities;
  final VoidCallback onOpenWorkQuickEntry;
  final VoidCallback onOpenLeaveQuickEntry;
  final ValueChanged<ActivityItem> onEditActivity;
  final ValueChanged<ActivityItem> onDeleteActivity;
  final WorkdaySession? workdaySession;
  final bool isSavingWorkdaySession;
  final Future<void> Function() onRecordWorkdayStartNow;
  final Future<void> Function() onStartWorkdayBreakNow;
  final Future<void> Function() onResumeWorkdayNow;
  final Future<void> Function() onFinishWorkdayNow;
  final Future<void> Function() onClearWorkdaySession;
  final Future<void> Function() onPickOverrideTargetMinutes;
  final Future<void> Function(CalendarTimeField field) onPickOverrideTime;
  final Future<void> Function() onPickOverrideBreakMinutes;
  final void Function({
    required int startMinutes,
    required int endMinutes,
    int? breakMinutes,
    int? pauseStartMinutes,
    int? pauseEndMinutes,
  })
  onAgendaSchedulePreviewChanged;
  final VoidCallback onAgendaSchedulePreviewCleared;
  final void Function({
    required int startMinutes,
    required int endMinutes,
    int? breakMinutes,
    int? pauseStartMinutes,
    int? pauseEndMinutes,
  })
  onAgendaScheduleChanged;
  final ValueChanged<bool> onAgendaInteractionChanged;
  final Future<void> Function(AppAppearanceSettings settings)
  onAppearanceSettingsChanged;
  final bool canUndoOverrideChanges;
  final bool canRedoOverrideChanges;
  final Future<void> Function() onUndoOverrideChange;
  final Future<void> Function() onRedoOverrideChange;
  final VoidCallback onMarkDayAsOff;
  final Future<void> Function(int minutes) onRegisterUnrecordedHours;
  final void Function(HomeSection section) onOpenSettingsSection;
  final Future<void> Function() onRestoreWorkingDay;
  final Future<void> Function(int exitMinutes) onConfirmSuggestedExitMinutes;
  final VoidCallback onOpenWorkSettings;
  final ValueChanged<int> onOvertimeLimitExceeded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveQuickEditorStartTime =
        quickEditorDaySchedule.startTime ?? overrideStartTimeController.text;
    final effectiveQuickEditorTargetText = formatHoursInput(
      quickEditorDaySchedule.targetMinutes,
    );
    final effectiveQuickEditorEndTime =
        quickEditorDaySchedule.endTime ?? overrideEndTimeController.text;
    final effectiveQuickEditorBreakMinutes = (() {
      final quickPauseWindow = quickEditorPauseWindow;
      if (quickPauseWindow == null) {
        return quickEditorDaySchedule.breakMinutes;
      }
      return quickPauseWindow.resumeMinutes -
          quickPauseWindow.pauseStartMinutes;
    })();
    final liveExpectedMinutes = resolveDisplayedExpectedMinutes(
      effectiveSchedule: effectiveDaySchedule,
      quickEditorSchedule: quickEditorDaySchedule,
    );
    final now = DateTime.now();
    final nowMinutes = (now.hour * 60) + now.minute;
    final workedView = resolveDayWorkedView(
      quickEditorSchedule: quickEditorDaySchedule,
      baseSchedule: baseDaySchedule,
      workRules: workRules,
      dayMetrics: dayMetrics,
      session: workdaySession,
      pauseWindow: quickEditorPauseWindow,
      rawStartTimeText: overrideStartTimeController.text,
      rawEndTimeText: overrideEndTimeController.text,
      isToday: isSelectedDateToday,
      nowMinutes: nowMinutes,
    );
    final controlInsights = buildQuickDayControlInsights(
      selectedDate: selectedDate,
      workRules: workRules,
      days: days,
      weekMetrics: weekMetrics,
      liveExpectedMinutes: liveExpectedMinutes,
      liveWorkedMinutes: workedView.workedMinutes,
      liveLeaveMinutes: dayMetrics.leaveMinutes,
      hasLiveResultContext: workedView.hasResultContext,
    );
    final liveDayBalanceMinutes = controlInsights.controlledBalanceMinutes;
    final monthBalanceInfo = buildDisplayedMonthBalanceInfo(
      selectedDate: selectedDate,
      days: days,
      liveExpectedMinutes: liveExpectedMinutes,
      liveWorkedMinutes: workedView.workedMinutes,
      liveLeaveMinutes: dayMetrics.leaveMinutes,
    );
    final periodBalanceInfo = buildDisplayedPeriodBalanceInfo(
      selectedDate: selectedDate,
      days: days,
      weekMetrics: weekMetrics,
      aggregation: appearanceSettings.dayBalanceAggregation,
      liveExpectedMinutes: liveExpectedMinutes,
      liveWorkedMinutes: workedView.workedMinutes,
      liveLeaveMinutes: dayMetrics.leaveMinutes,
    );
    if (isSelectedDateToday && controlInsights.exceededOvertimeMinutes > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        onOvertimeLimitExceeded(controlInsights.exceededOvertimeMinutes);
      });
    } else if (isSelectedDateToday) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        onOvertimeLimitExceeded(0);
      });
    }
    final exitView = resolveDayExitView(
      effectiveSchedule: effectiveDaySchedule,
      quickEditorSchedule: quickEditorDaySchedule,
      workRules: workRules,
      scheduledEndTimeText: effectiveQuickEditorEndTime,
      rawStartTimeText: overrideStartTimeController.text,
      rawEndTimeText: overrideEndTimeController.text,
      isDayOff: workedView.isDayOff,
      isToday: isSelectedDateToday,
      hasResultContext: workedView.hasResultContext,
      hasSuggestionContext: workedView.hasExitSuggestionContext,
      session: workdaySession,
      nowMinutes: nowMinutes,
      pendingConfirmationMinutes: pendingExitConfirmationMinutes,
    );
    final isUsingStandardSchedule = matchesDaySchedule(
      baseDaySchedule,
      quickEditorDaySchedule,
    );
    final isUsingStandardWorkTarget =
        quickEditorDaySchedule.targetMinutes == baseDaySchedule.targetMinutes;
    final canRestoreWorkingDay =
        workedView.isDayOff && !isUsingStandardSchedule;
    // Tornare all'orario standard deve essere possibile anche quando
    // l'eccezione del giorno non e' una giornata libera.
    final canRestoreStandardSchedule =
        dayMetrics.hasOverride && !isUsingStandardSchedule;
    final selectedDayInfo = switch (compareDateToToday(selectedDate)) {
      0 => (
        label: 'Oggi',
        icon: Icons.today_outlined,
        color: theme.colorScheme.primary,
      ),
      < 0 => (
        label: 'Passato',
        icon: Icons.history,
        color: theme.colorScheme.secondary,
      ),
      _ => (
        label: 'Futuro',
        icon: Icons.upcoming_outlined,
        color: theme.colorScheme.tertiary,
      ),
    };
    final showWorkdaySessionCard =
        appearanceSettings.showDayWorkdayCard && isSelectedDateToday;
    final workdaySessionSpacing = appearanceSettings.expandDayWorkdayCard
        ? 18.0
        : 8.0;
    final quickEditorSpacing = appearanceSettings.expandDayQuickEditor
        ? 18.0
        : 8.0;
    final quickEditor = Form(
      key: overrideFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CalendarQuickScheduleEditor(
            isExpanded: appearanceSettings.expandDayQuickEditor,
            targetText: effectiveQuickEditorTargetText,
            startTimeText: effectiveQuickEditorStartTime,
            endTimeText: effectiveQuickEditorEndTime,
            plannedStartTimeText: plannedDaySchedule.startTime ?? '',
            plannedEndTimeText: plannedDaySchedule.endTime ?? '',
            suggestedExitLabel: exitView.suggestedLabel,
            hasExitSuggestionContext: workedView.hasExitSuggestionContext,
            breakMinutes: effectiveQuickEditorBreakMinutes,
            showEndTime: appearanceSettings.showDayEndTime,
            showBreakMinutes: appearanceSettings.showDayBreakMinutes,
            onPickTargetMinutes: onPickOverrideTargetMinutes,
            onPickStartTime: () => onPickOverrideTime(CalendarTimeField.start),
            onPickEndTime: () => onPickOverrideTime(CalendarTimeField.end),
            onPickBreakMinutes: onPickOverrideBreakMinutes,
            canUndoChanges: canUndoOverrideChanges,
            canRedoChanges: canRedoOverrideChanges,
            onUndoChange: onUndoOverrideChange,
            onRedoChange: onRedoOverrideChange,
            onToggleExpanded: (expanded) => unawaited(
              onAppearanceSettingsChanged(
                appearanceSettings.copyWith(expandDayQuickEditor: expanded),
              ),
            ),
            onMarkDayAsOff: onMarkDayAsOff,
            onRestoreWorkingDay: onRestoreWorkingDay,
            isDayOff: workedView.isDayOff,
            canRestoreWorkingDay: canRestoreWorkingDay,
            canRestoreStandardSchedule: canRestoreStandardSchedule,
            workedMinutes: workedView.workedMinutes,
            todayBalanceMinutes: liveDayBalanceMinutes,
            overtimeMinutes: controlInsights.todayOvertimeMinutes,
            exceededOvertimeMinutes: controlInsights.exceededOvertimeMinutes,
            showOvertimeConfigurationHint:
                controlInsights.showConfigurationHint,
            overtimeConfigurationHint: controlInsights.configurationHint,
            limitWarningText: controlInsights.limitWarningText,
            monthBalanceInfo: monthBalanceInfo,
            periodBalanceInfo: periodBalanceInfo,
            dayBalanceAggregation: appearanceSettings.dayBalanceAggregation,
            onDayBalanceAggregationChanged: (aggregation) => unawaited(
              onAppearanceSettingsChanged(
                appearanceSettings.copyWith(dayBalanceAggregation: aggregation),
              ),
            ),
            remainingToProgrammedExitLabel: exitView.remainingLabel,
            expectedMinutes: liveExpectedMinutes,
            unrecordedMinutes: workedView.unrecordedMinutes,
            onOpenSettingsSection: onOpenSettingsSection,
            onRegisterUnrecordedHours: workedView.unrecordedMinutes == null
                ? null
                : () => unawaited(
                    onRegisterUnrecordedHours(workedView.unrecordedMinutes!),
                  ),
            hasResultContext: workedView.hasResultContext,
            hasTheoreticalExit: exitView.isForecast,
            hasPendingExitConfirmation: exitView.hasPendingConfirmation,
            isUsingStandardWorkTarget: isUsingStandardWorkTarget,
            collapsedSummary: buildQuickDaySummaryLabel(
              isDayOff: workedView.isDayOff,
              hasResultContext: workedView.hasResultContext,
              workedMinutes: workedView.workedMinutes,
              startTimeText: effectiveQuickEditorStartTime,
              endTimeText: effectiveQuickEditorEndTime,
              plannedStartTimeText: plannedDaySchedule.startTime ?? '',
              plannedEndTimeText: plannedDaySchedule.endTime ?? '',
              targetText: effectiveQuickEditorTargetText,
            ),
            dayActivities: dayActivities,
            onAddWork: onOpenWorkQuickEntry,
            onAddLeave: onOpenLeaveQuickEntry,
            onEditActivity: onEditActivity,
            onDeleteActivity: onDeleteActivity,
            onOpenWorkSettings: onOpenWorkSettings,
            isEndTimeFinalized:
                effectiveQuickEditorEndTime.trim().isNotEmpty &&
                (!isSelectedDateToday ||
                    workedView.hasElapsedManualExit ||
                    (workdaySession?.isCompleted ?? false)),
            onConfirmTheoreticalExit: exitView.confirmableMinutes == null
                ? null
                : () => onConfirmSuggestedExitMinutes(
                    exitView.confirmableMinutes!,
                  ),
          ),
        ],
      ),
    );
    final dayTimeline = CalendarPeriodSummary(
      calendarView: calendarView,
      days: days,
      dayMetrics: dayMetrics,
      daySchedule: draftDaySchedule,
      dayPauseWindow: selectedDayPauseWindow,
      isDayScheduleProvisional:
          isSelectedDateToday &&
          workdaySession != null &&
          !workdaySession!.isCompleted,
      workdaySession: isSelectedDateToday ? workdaySession : null,
      weekMetrics: isSelectedDateToday
          ? weekMetrics
                .map((metric) {
                  if (!isSameDay(metric.date, selectedDate)) {
                    return metric;
                  }

                  final rawLiveBalanceMinutes =
                      (workedView.workedMinutes + metric.leaveMinutes) -
                      liveExpectedMinutes;
                  return DayMetrics(
                    date: metric.date,
                    expectedMinutes: liveExpectedMinutes,
                    workedMinutes: workedView.workedMinutes,
                    leaveMinutes: metric.leaveMinutes,
                    rawBalanceMinutes: rawLiveBalanceMinutes,
                    balanceMinutes: rawLiveBalanceMinutes,
                    hasOverride:
                        metric.hasOverride ||
                        workedView.hasWorkedOverride ||
                        exitView.hasPendingConfirmation,
                    schedule: quickEditorDaySchedule,
                    overrideNote: metric.overrideNote,
                  );
                })
                .toList(growable: false)
          : weekMetrics,
      monthMetrics: monthMetrics,
      yearMetrics: yearMetrics,
      selectedDate: selectedDate,
      onSelectDate: onSelectDate,
      onOpenDay: onOpenDay,
      onCalendarViewChanged: onCalendarViewChanged,
      onDaySchedulePreviewChanged: onAgendaSchedulePreviewChanged,
      onDaySchedulePreviewCleared: onAgendaSchedulePreviewCleared,
      onDayScheduleChanged: onAgendaScheduleChanged,
      onAgendaInteractionChanged: onAgendaInteractionChanged,
      isDayAgendaExpanded: appearanceSettings.expandDayAgenda,
      onToggleDayAgendaExpanded: (expanded) => unawaited(
        onAppearanceSettingsChanged(
          appearanceSettings.copyWith(expandDayAgenda: expanded),
        ),
      ),
    );

    final trailing = calendarView == CalendarView.day
        ? Row(
            children: [
              Expanded(
                child: CalendarPeriodSwitcher(
                  periodLabel: periodLabel,
                  onPreviousPeriod: onPreviousPeriod,
                  onNextPeriod: onNextPeriod,
                ),
              ),
              const SizedBox(width: 10),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  CalendarDateRelationBadge(
                    label: selectedDayInfo.label,
                    icon: selectedDayInfo.icon,
                    color: selectedDayInfo.color,
                  ),
                  if (isLoadingCalendarData) ...[
                    const SizedBox(height: 6),
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ],
                ],
              ),
            ],
          )
        : Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              CalendarPeriodSwitcher(
                periodLabel: periodLabel,
                onPreviousPeriod: onPreviousPeriod,
                onNextPeriod: onNextPeriod,
              ),
              if (isLoadingCalendarData)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          );
    final compactCalendarTabs = MediaQuery.of(context).size.width <= 430;

    return SectionCard(
      title: title,
      trailing: trailing,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showViewSelector)
            LayoutBuilder(
              builder: (context, constraints) {
                final selector = SegmentedButton<CalendarView>(
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment<CalendarView>(
                      value: CalendarView.week,
                      label: Text('Settimana'),
                      icon: compactCalendarTabs
                          ? null
                          : const Icon(Icons.view_week_outlined),
                    ),
                    ButtonSegment<CalendarView>(
                      value: CalendarView.month,
                      label: Text('Mese'),
                      icon: compactCalendarTabs
                          ? null
                          : const Icon(Icons.calendar_month_outlined),
                    ),
                    ButtonSegment<CalendarView>(
                      value: CalendarView.year,
                      label: Text('Anno'),
                      icon: compactCalendarTabs
                          ? null
                          : const Icon(Icons.calendar_view_month_outlined),
                    ),
                  ],
                  selected: {calendarViewOrDefault(calendarView)},
                  onSelectionChanged: (selection) {
                    if (selection.isEmpty) {
                      return;
                    }
                    unawaited(onCalendarViewChanged(selection.first));
                  },
                );

                if (compactCalendarTabs) {
                  return SizedBox(width: constraints.maxWidth, child: selector);
                }

                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: selector,
                );
              },
            ),
          if (calendarView == CalendarView.day && showWorkdaySessionCard) ...[
            SizedBox(height: workdaySessionSpacing),
            WorkdaySessionCard(
              isExpanded: appearanceSettings.expandDayWorkdayCard,
              session: workdaySession,
              schedule: effectiveDaySchedule,
              pauseWindow: selectedDayPauseWindow,
              isBusy: isSavingWorkdaySession,
              flexibleEntryWindowLabel: isSelectedDateToday
                  ? resolveFlexibleEntryWindowLabel(
                      workRules: workRules,
                      schedule: plannedDaySchedule,
                    )
                  : null,
              onToggleExpanded: (expanded) => unawaited(
                onAppearanceSettingsChanged(
                  appearanceSettings.copyWith(expandDayWorkdayCard: expanded),
                ),
              ),
              onRecordNow: onRecordWorkdayStartNow,
              onStartBreak: onStartWorkdayBreakNow,
              onResume: onResumeWorkdayNow,
              onFinish: onFinishWorkdayNow,
              onClear: workdaySession == null ? null : onClearWorkdaySession,
            ),
          ],
          if (calendarView == CalendarView.day) ...[
            SizedBox(height: quickEditorSpacing),
            if (appearanceSettings.dayCalendarLayoutMode ==
                DayCalendarLayoutMode.quickEditorFirst)
              quickEditor
            else
              dayTimeline,
            SizedBox(height: quickEditorSpacing),
            if (appearanceSettings.dayCalendarLayoutMode ==
                DayCalendarLayoutMode.quickEditorFirst)
              dayTimeline
            else
              quickEditor,
          ],
          if (calendarView != CalendarView.day) ...[
            const SizedBox(height: 18),
            dayTimeline,
          ],
        ],
      ),
    );
  }
}
