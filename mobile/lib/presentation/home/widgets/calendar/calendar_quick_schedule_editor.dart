// Editor rapido dell'orario del giorno selezionato.

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:work_hours_mobile/application/services/theme_preference_store.dart';
import 'package:work_hours_mobile/presentation/home/logic/quick_day_insights.dart';
import 'package:work_hours_mobile/presentation/home/widgets/calendar/quick_day_summary.dart';

class CalendarQuickScheduleEditor extends StatelessWidget {
  const CalendarQuickScheduleEditor({
    super.key,
    required this.isExpanded,
    required this.targetText,
    required this.startTimeText,
    required this.endTimeText,
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
    required this.workedMinutesAtProgrammedExit,
    required this.hasResultContext,
    required this.hasTheoreticalExit,
    required this.hasPendingExitConfirmation,
    required this.isUsingStandardWorkTarget,
    required this.isEndTimeFinalized,
    this.onConfirmTheoreticalExit,
  });

  final bool isExpanded;
  final String targetText;
  final String startTimeText;
  final String endTimeText;
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
  final int? workedMinutesAtProgrammedExit;
  final bool hasResultContext;
  final bool hasTheoreticalExit;
  final bool hasPendingExitConfirmation;
  final bool isUsingStandardWorkTarget;
  final bool isEndTimeFinalized;
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
    final standardScheduleColor = theme.colorScheme.onSurfaceVariant;
    const pendingExitColor = Color(0xFFBF7A24);
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
    final values = <Widget>[
      QuickScheduleValue(
        label: 'Entrata',
        value: startTimeText.isEmpty ? '--:--' : startTimeText,
        valueKey: const ValueKey('calendar-override-start-time-button'),
        supportingText: !hasResultContext && !isDayOff ? 'Inizia da qui' : null,
        isPrimaryAction: !hasResultContext && !isDayOff,
        onTap: onPickStartTime,
      ),
      if (showEndTime)
        QuickScheduleValue(
          label: hasPendingExitConfirmation
              ? 'Uscita programmata'
              : hasTheoreticalExit
              ? 'Uscita teorica'
              : (isProgrammedExit ? 'Uscita programmata' : 'Uscita'),
          value: hasPendingExitConfirmation
              ? (endTimeText.isEmpty ? suggestedExitLabel : endTimeText)
              : hasTheoreticalExit
              ? suggestedExitLabel
              : (endTimeText.isEmpty ? '--:--' : endTimeText),
          valueKey: const ValueKey('calendar-override-end-time-button'),
          supportingText: hasPendingExitConfirmation
              ? null
              : hasTheoreticalExit
              ? 'Calcolata su entrata + ore attese'
              : (endTimeText.isEmpty && !isDayOff ? 'Dopo l\'entrata' : null),
          labelColorOverride: hasPendingExitConfirmation || hasTheoreticalExit
              ? pendingExitColor
              : null,
          valueColorOverride: hasPendingExitConfirmation || hasTheoreticalExit
              ? pendingExitColor
              : null,
          secondaryActionLabel: hasPendingExitConfirmation || hasTheoreticalExit
              ? 'Conferma'
              : null,
          secondaryActionKey: const ValueKey(
            'calendar-override-confirm-theoretical-end-button',
          ),
          onSecondaryAction:
              (hasPendingExitConfirmation || hasTheoreticalExit) &&
                  onConfirmTheoreticalExit != null
              ? () => onConfirmTheoreticalExit!()
              : null,
          onTap: onPickEndTime,
        ),
      QuickScheduleValue(
        label: isUsingStandardWorkTarget
            ? 'Ore di lavoro standard'
            : 'Ore di lavoro',
        value: targetText.isEmpty ? '--' : targetText,
        valueKey: const ValueKey('calendar-override-target-value'),
        labelColorOverride: isUsingStandardWorkTarget
            ? standardScheduleColor
            : null,
        valueColorOverride: isUsingStandardWorkTarget
            ? standardScheduleColor
            : null,
        onTap: onPickTargetMinutes,
      ),
      if (showBreakMinutes)
        QuickScheduleValue(
          label: 'Pausa',
          value: breakMinutes == 0 ? '0 min' : '$breakMinutes min',
          valueKey: const ValueKey('calendar-override-break-value'),
          onTap: onPickBreakMinutes,
        ),
    ];

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
          SizedBox(
            height: 30,
            child: Align(alignment: Alignment.centerLeft, child: header),
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
                      ],
                    ),
                    const SizedBox(height: 12),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final columnCount = math.min(
                          values.length,
                          constraints.maxWidth >= 720
                              ? 4
                              : (constraints.maxWidth >= 540 ? 3 : 2),
                        );
                        const spacing = 12.0;
                        final itemWidth = columnCount <= 1
                            ? constraints.maxWidth
                            : (constraints.maxWidth -
                                      (spacing * (columnCount - 1))) /
                                  columnCount;

                        return Wrap(
                          spacing: spacing,
                          runSpacing: 12,
                          children: [
                            for (final value in values)
                              SizedBox(width: itemWidth, child: value),
                          ],
                        );
                      },
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
                      workedMinutesAtProgrammedExit:
                          workedMinutesAtProgrammedExit,
                      onOpenWorkSettings: onOpenWorkSettings,
                      isDayOff: isDayOff,
                      hasResultContext: hasResultContext,
                    ),
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
