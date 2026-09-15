// Editor rapido dell'orario del giorno selezionato.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:work_hours_mobile/application/services/theme_preference_store.dart';
import 'package:work_hours_mobile/presentation/home/logic/quick_day_insights.dart';
import 'package:work_hours_mobile/presentation/home/models/activity_item.dart';
import 'package:work_hours_mobile/presentation/home/widgets/calendar/quick_day_registrations.dart';
import 'package:work_hours_mobile/presentation/home/widgets/calendar/quick_day_schedule_fields.dart';
import 'package:work_hours_mobile/presentation/home/widgets/calendar/quick_day_summary.dart';

class CalendarQuickScheduleEditor extends StatelessWidget {
  const CalendarQuickScheduleEditor({
    super.key,
    required this.isExpanded,
    required this.targetText,
    required this.startTimeText,
    required this.endTimeText,
    required this.plannedStartTimeText,
    required this.plannedEndTimeText,
    required this.suggestedExitLabel,
    required this.hasExitSuggestionContext,
    required this.breakMinutes,
    required this.showEndTime,
    required this.showBreakMinutes,
    required this.onPickTargetMinutes,
    required this.onPickStartTime,
    required this.onPickEndTime,
    required this.onPickBreakMinutes,
    required this.canUndoChanges,
    required this.canRedoChanges,
    required this.onUndoChange,
    required this.onRedoChange,
    required this.onToggleExpanded,
    required this.onMarkDayAsOff,
    required this.onRestoreWorkingDay,
    required this.isDayOff,
    required this.canRestoreWorkingDay,
    required this.canRestoreStandardSchedule,
    required this.workedMinutes,
    required this.todayBalanceMinutes,
    required this.overtimeMinutes,
    required this.exceededOvertimeMinutes,
    required this.showOvertimeConfigurationHint,
    required this.overtimeConfigurationHint,
    required this.limitWarningText,
    required this.monthBalanceInfo,
    required this.periodBalanceInfo,
    required this.dayBalanceAggregation,
    required this.onDayBalanceAggregationChanged,
    required this.onOpenWorkSettings,
    required this.remainingToProgrammedExitLabel,
    required this.expectedMinutes,
    required this.unrecordedMinutes,
    required this.onRegisterUnrecordedHours,
    required this.hasResultContext,
    required this.hasTheoreticalExit,
    required this.hasPendingExitConfirmation,
    required this.isUsingStandardWorkTarget,
    required this.isEndTimeFinalized,
    required this.collapsedSummary,
    required this.dayActivities,
    required this.onAddWork,
    required this.onAddLeave,
    required this.onEditActivity,
    required this.onDeleteActivity,
    this.onConfirmTheoreticalExit,
  });

  final bool isExpanded;
  final String targetText;
  final String startTimeText;
  final String endTimeText;

  /// Entrata e uscita previste dal piano del giorno, gia' pronte nei campi
  /// finche' non viene registrato o modificato nulla.
  final String plannedStartTimeText;
  final String plannedEndTimeText;
  final String suggestedExitLabel;
  final bool hasExitSuggestionContext;
  final int breakMinutes;
  final bool showEndTime;
  final bool showBreakMinutes;
  final Future<void> Function() onPickTargetMinutes;
  final Future<void> Function() onPickStartTime;
  final Future<void> Function() onPickEndTime;
  final Future<void> Function() onPickBreakMinutes;
  final bool canUndoChanges;
  final bool canRedoChanges;
  final Future<void> Function() onUndoChange;
  final Future<void> Function() onRedoChange;
  final ValueChanged<bool> onToggleExpanded;
  final VoidCallback onMarkDayAsOff;
  final Future<void> Function() onRestoreWorkingDay;
  final bool isDayOff;
  final bool canRestoreWorkingDay;

  /// Il giorno ha un'eccezione salvata che si puo' riportare allo standard.
  final bool canRestoreStandardSchedule;
  final int workedMinutes;
  final int todayBalanceMinutes;
  final int overtimeMinutes;
  final int exceededOvertimeMinutes;
  final bool showOvertimeConfigurationHint;
  final String? overtimeConfigurationHint;
  final String? limitWarningText;
  final DisplayedMonthBalanceInfo monthBalanceInfo;
  final DisplayedPeriodBalanceInfo periodBalanceInfo;
  final DayBalanceAggregation dayBalanceAggregation;
  final ValueChanged<DayBalanceAggregation> onDayBalanceAggregationChanged;
  final VoidCallback onOpenWorkSettings;
  final String? remainingToProgrammedExitLabel;
  final int expectedMinutes;
  final int? unrecordedMinutes;
  final VoidCallback? onRegisterUnrecordedHours;
  final bool hasResultContext;
  final bool hasTheoreticalExit;
  final bool hasPendingExitConfirmation;
  final bool isUsingStandardWorkTarget;
  final bool isEndTimeFinalized;

  /// Riga mostrata quando il riquadro e' chiuso: evita di doverlo aprire.
  final String collapsedSummary;
  final List<ActivityItem> dayActivities;
  final VoidCallback onAddWork;
  final VoidCallback onAddLeave;
  final ValueChanged<ActivityItem> onEditActivity;
  final ValueChanged<ActivityItem> onDeleteActivity;
  final Future<void> Function()? onConfirmTheoreticalExit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final toggleButtonSize = isExpanded ? 36.0 : 30.0;
    final toggleIconSize = isExpanded ? 20.0 : 18.0;
    final expandedIcon = isExpanded
        ? Icons.keyboard_arrow_up_rounded
        : Icons.keyboard_arrow_down_rounded;
    final isProgrammedExit =
        endTimeText.trim().isNotEmpty &&
        hasExitSuggestionContext &&
        !isEndTimeFinalized;
    final toggleButton = IconButton(
      key: const ValueKey('calendar-quick-editor-toggle-button'),
      onPressed: () => onToggleExpanded(!isExpanded),
      tooltip: isExpanded
          ? 'Riduci modifica rapida'
          : 'Espandi modifica rapida',
      visualDensity: VisualDensity.compact,
      iconSize: toggleIconSize,
      splashRadius: isExpanded ? 18 : 16,
      constraints: BoxConstraints.tightFor(
        width: toggleButtonSize,
        height: toggleButtonSize,
      ),
      padding: EdgeInsets.zero,
      icon: Icon(expandedIcon),
    );
    final header = Row(
      children: [
        Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => onToggleExpanded(!isExpanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                'Modifica rapida',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),
        if (isExpanded) ...[
          IconButton(
            key: const ValueKey('calendar-override-undo-button'),
            onPressed: canUndoChanges ? () => onUndoChange() : null,
            tooltip: 'Annulla modifica',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.undo_rounded),
          ),
          IconButton(
            key: const ValueKey('calendar-override-redo-button'),
            onPressed: canRedoChanges ? () => onRedoChange() : null,
            tooltip: 'Ripristina modifica',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.redo_rounded),
          ),
        ],
        toggleButton,
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isExpanded)
          header
        else
          // Il riepilogo va sotto il titolo, non di fianco: di fianco sfora
          // sugli schermi stretti, dove l'app viene usata davvero.
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              header,
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => onToggleExpanded(true),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    collapsedSummary,
                    key: const ValueKey('calendar-quick-editor-summary'),
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
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
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        FilterChip(
                          key: const ValueKey(
                            'calendar-override-day-off-button',
                          ),
                          selected: isDayOff,
                          showCheckmark: false,
                          avatar: Icon(
                            isDayOff
                                ? Icons.event_busy_outlined
                                : Icons.event_available_outlined,
                            size: 18,
                          ),
                          label: Text(
                            isDayOff ? 'Giornata libera' : 'Segna libera',
                          ),
                          onSelected: (selected) {
                            if (selected) {
                              onMarkDayAsOff();
                              return;
                            }
                            if (canRestoreWorkingDay) {
                              unawaited(onRestoreWorkingDay());
                            }
                          },
                        ),
                        if (canRestoreStandardSchedule)
                          ActionChip(
                            key: const ValueKey(
                              'quick-day-restore-standard-chip',
                            ),
                            avatar: const Icon(Icons.restart_alt, size: 18),
                            label: const Text('Ripristina standard'),
                            onPressed: () => unawaited(onRestoreWorkingDay()),
                          ),
                        ActionChip(
                          key: const ValueKey('quick-day-add-work-chip'),
                          avatar: const Icon(Icons.more_time_rounded, size: 18),
                          label: const Text('Aggiungi ore'),
                          onPressed: onAddWork,
                        ),
                        ActionChip(
                          key: const ValueKey('quick-day-add-leave-chip'),
                          avatar: const Icon(
                            Icons.event_busy_outlined,
                            size: 18,
                          ),
                          label: const Text('Aggiungi causale'),
                          onPressed: onAddLeave,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    QuickDayScheduleFields(
                      targetText: targetText,
                      startTimeText: startTimeText,
                      endTimeText: endTimeText,
                      plannedStartTimeText: plannedStartTimeText,
                      plannedEndTimeText: plannedEndTimeText,
                      suggestedExitLabel: suggestedExitLabel,
                      breakMinutes: breakMinutes,
                      showEndTime: showEndTime,
                      showBreakMinutes: showBreakMinutes,
                      isDayOff: isDayOff,
                      hasResultContext: hasResultContext,
                      hasProgrammedExit: isProgrammedExit,
                      hasTheoreticalExit: hasTheoreticalExit,
                      hasPendingExitConfirmation: hasPendingExitConfirmation,
                      isUsingStandardWorkTarget: isUsingStandardWorkTarget,
                      onPickTargetMinutes: onPickTargetMinutes,
                      onPickStartTime: onPickStartTime,
                      onPickEndTime: onPickEndTime,
                      onPickBreakMinutes: onPickBreakMinutes,
                      onConfirmTheoreticalExit: onConfirmTheoreticalExit,
                    ),
                    const SizedBox(height: 14),
                    QuickDayComputedSummary(
                      workedMinutes: workedMinutes,
                      todayBalanceMinutes: todayBalanceMinutes,
                      overtimeMinutes: overtimeMinutes,
                      exceededOvertimeMinutes: exceededOvertimeMinutes,
                      showOvertimeConfigurationHint:
                          showOvertimeConfigurationHint,
                      overtimeConfigurationHint: overtimeConfigurationHint,
                      limitWarningText: limitWarningText,
                      monthBalanceInfo: monthBalanceInfo,
                      periodBalanceInfo: periodBalanceInfo,
                      dayBalanceAggregation: dayBalanceAggregation,
                      onDayBalanceAggregationChanged:
                          onDayBalanceAggregationChanged,
                      remainingToProgrammedExitLabel:
                          remainingToProgrammedExitLabel,
                      expectedMinutes: expectedMinutes,
                      unrecordedMinutes: unrecordedMinutes,
                      onRegisterUnrecordedHours: onRegisterUnrecordedHours,
                      onOpenWorkSettings: onOpenWorkSettings,
                      isDayOff: isDayOff,
                      hasResultContext: hasResultContext,
                    ),
                    if (dayActivities.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      QuickDayRegistrations(
                        dayActivities: dayActivities,
                        onEditActivity: onEditActivity,
                        onDeleteActivity: onDeleteActivity,
                      ),
                    ],
                    if (!hasExitSuggestionContext && !isDayOff) ...[
                      const SizedBox(height: 10),
                      Text(
                        'Inserisci l\'entrata per iniziare.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
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
