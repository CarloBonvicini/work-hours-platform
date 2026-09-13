// Campi entrata, uscita, ore e pausa della modifica rapida del giorno.

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:work_hours_mobile/presentation/home/widgets/calendar/quick_day_summary.dart';

/// Arancio delle uscite ancora da confermare (programmata o teorica).
const Color quickDayPendingExitColor = Color(0xFFBF7A24);

class QuickDayScheduleFields extends StatelessWidget {
  const QuickDayScheduleFields({
    super.key,
    required this.targetText,
    required this.startTimeText,
    required this.endTimeText,
    required this.plannedStartTimeText,
    required this.plannedEndTimeText,
    required this.suggestedExitLabel,
    required this.breakMinutes,
    required this.showEndTime,
    required this.showBreakMinutes,
    required this.isDayOff,
    required this.hasResultContext,
    required this.hasProgrammedExit,
    required this.hasTheoreticalExit,
    required this.hasPendingExitConfirmation,
    required this.isUsingStandardWorkTarget,
    required this.onPickTargetMinutes,
    required this.onPickStartTime,
    required this.onPickEndTime,
    required this.onPickBreakMinutes,
    this.onConfirmTheoreticalExit,
  });

  final String targetText;
  final String startTimeText;
  final String endTimeText;
  final String plannedStartTimeText;
  final String plannedEndTimeText;
  final String suggestedExitLabel;
  final int breakMinutes;
  final bool showEndTime;
  final bool showBreakMinutes;
  final bool isDayOff;
  final bool hasResultContext;
  final bool hasProgrammedExit;
  final bool hasTheoreticalExit;
  final bool hasPendingExitConfirmation;
  final bool isUsingStandardWorkTarget;
  final Future<void> Function() onPickTargetMinutes;
  final Future<void> Function() onPickStartTime;
  final Future<void> Function() onPickEndTime;
  final Future<void> Function() onPickBreakMinutes;
  final Future<void> Function()? onConfirmTheoreticalExit;

  /// Entrata mostrata: quella registrata oppure, se manca, quella prevista.
  bool get _isPlannedStart =>
      startTimeText.isEmpty && !isDayOff && plannedStartTimeText.isNotEmpty;

  /// Uscita prevista: vale solo se non c'e' gia' un'uscita calcolata o salvata.
  bool get _isPlannedEnd =>
      endTimeText.isEmpty &&
      !isDayOff &&
      !hasPendingExitConfirmation &&
      !hasTheoreticalExit &&
      plannedEndTimeText.isNotEmpty;

  Widget _startField(Color plannedColor) {
    final displayedText = _isPlannedStart ? plannedStartTimeText : startTimeText;
    return QuickScheduleValue(
      label: 'Entrata',
      value: displayedText.isEmpty ? '--:--' : displayedText,
      valueKey: const ValueKey('calendar-override-start-time-button'),
      supportingText: hasResultContext || isDayOff
          ? null
          : (_isPlannedStart ? 'Previsto: conferma o cambia' : 'Inizia da qui'),
      isPrimaryAction: !hasResultContext && !isDayOff && !_isPlannedStart,
      labelColorOverride: _isPlannedStart ? plannedColor : null,
      valueColorOverride: _isPlannedStart ? plannedColor : null,
      onTap: onPickStartTime,
    );
  }

  Widget _endField(Color plannedColor) {
    final isConfirmable = hasPendingExitConfirmation || hasTheoreticalExit;
    return QuickScheduleValue(
      label: hasPendingExitConfirmation
          ? 'Uscita programmata'
          : hasTheoreticalExit
          ? 'Uscita teorica'
          : _isPlannedEnd
          ? 'Uscita prevista'
          : (hasProgrammedExit ? 'Uscita programmata' : 'Uscita'),
      value: hasPendingExitConfirmation
          ? (endTimeText.isEmpty ? suggestedExitLabel : endTimeText)
          : hasTheoreticalExit
          ? suggestedExitLabel
          : _isPlannedEnd
          ? plannedEndTimeText
          : (endTimeText.isEmpty ? '--:--' : endTimeText),
      valueKey: const ValueKey('calendar-override-end-time-button'),
      supportingText: hasPendingExitConfirmation
          ? null
          : hasTheoreticalExit
          ? 'Calcolata su entrata + ore attese'
          : _isPlannedEnd
          ? 'Previsto: conferma o cambia'
          : (endTimeText.isEmpty && !isDayOff ? 'Dopo l\'entrata' : null),
      labelColorOverride: isConfirmable
          ? quickDayPendingExitColor
          : (_isPlannedEnd ? plannedColor : null),
      valueColorOverride: isConfirmable
          ? quickDayPendingExitColor
          : (_isPlannedEnd ? plannedColor : null),
      secondaryActionLabel: isConfirmable ? 'Conferma' : null,
      secondaryActionKey: const ValueKey(
        'calendar-override-confirm-theoretical-end-button',
      ),
      onSecondaryAction: isConfirmable && onConfirmTheoreticalExit != null
          ? () => onConfirmTheoreticalExit!()
          : null,
      onTap: onPickEndTime,
    );
  }

  @override
  Widget build(BuildContext context) {
    final plannedColor = Theme.of(context).colorScheme.onSurfaceVariant;
    final values = <Widget>[
      _startField(plannedColor),
      if (showEndTime) _endField(plannedColor),
      QuickScheduleValue(
        label: isUsingStandardWorkTarget
            ? 'Ore di lavoro standard'
            : 'Ore di lavoro',
        value: targetText.isEmpty ? '--' : targetText,
        valueKey: const ValueKey('calendar-override-target-value'),
        labelColorOverride: isUsingStandardWorkTarget ? plannedColor : null,
        valueColorOverride: isUsingStandardWorkTarget ? plannedColor : null,
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

    return LayoutBuilder(
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
            : (constraints.maxWidth - (spacing * (columnCount - 1))) /
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
    );
  }
}
