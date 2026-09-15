// Valori e riepilogo calcolato dell'editor rapido del giorno.

import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:work_hours_mobile/application/services/hour_input_parser.dart';
import 'package:work_hours_mobile/application/services/theme_preference_store.dart';
import 'package:work_hours_mobile/presentation/home/logic/hours_labels.dart';
import 'package:work_hours_mobile/presentation/home/logic/quick_day_insights.dart';
import 'package:work_hours_mobile/presentation/home/widgets/calendar/quick_day_hero.dart';

class QuickScheduleValue extends StatelessWidget {
  const QuickScheduleValue({
    super.key,
    required this.label,
    required this.value,
    required this.valueKey,
    required this.onTap,
    this.supportingText,
    this.isPrimaryAction = false,
    this.labelColorOverride,
    this.valueColorOverride,
    this.secondaryActionLabel,
    this.secondaryActionKey,
    this.onSecondaryAction,
  });

  final String label;
  final String value;
  final Key valueKey;
  final Future<void> Function() onTap;
  final String? supportingText;
  final bool isPrimaryAction;
  final Color? labelColorOverride;
  final Color? valueColorOverride;
  final String? secondaryActionLabel;
  final Key? secondaryActionKey;
  final Future<void> Function()? onSecondaryAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final labelColor =
        labelColorOverride ??
        (isPrimaryAction ? colorScheme.primary : colorScheme.onSurface);
    final supportingColor = isPrimaryAction
        ? colorScheme.primary.withValues(alpha: 0.88)
        : colorScheme.onSurfaceVariant;
    final valueColor = valueColorOverride ?? colorScheme.primary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: valueKey,
        borderRadius: BorderRadius.circular(14),
        onTap: () => onTap(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: labelColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      value,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: valueColor,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    CupertinoIcons.chevron_up_chevron_down,
                    size: 16,
                    color: colorScheme.primary,
                  ),
                ],
              ),
              if (supportingText != null) ...[
                const SizedBox(height: 4),
                Text(
                  supportingText!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: supportingColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              if (secondaryActionLabel != null &&
                  onSecondaryAction != null) ...[
                const SizedBox(height: 4),
                TextButton(
                  key: secondaryActionKey,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 0),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                    foregroundColor: valueColor,
                    textStyle: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onPressed: () => onSecondaryAction!(),
                  child: Text(secondaryActionLabel!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class QuickDayComputedSummary extends StatelessWidget {
  const QuickDayComputedSummary({
    super.key,
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
    required this.remainingToProgrammedExitLabel,
    required this.expectedMinutes,
    required this.unrecordedMinutes,
    required this.onRegisterUnrecordedHours,
    required this.onOpenWorkSettings,
    required this.isDayOff,
    required this.hasResultContext,
  });

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
  final String? remainingToProgrammedExitLabel;
  final int expectedMinutes;
  final int? unrecordedMinutes;
  final VoidCallback? onRegisterUnrecordedHours;
  final VoidCallback onOpenWorkSettings;
  final bool isDayOff;
  final bool hasResultContext;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final hasStartedDay = hasResultContext && !isDayOff;
    final dayBalanceLabel = switch ((
      isDayOff,
      hasStartedDay,
      todayBalanceMinutes,
    )) {
      (true, _, _) => 'Saldo oggi',
      (false, false, _) => 'Saldo oggi',
      (false, true, > 0) => 'Credito',
      (false, true, < 0) => 'Debito',
      _ => 'In pari oggi',
    };
    final dayBalanceValue = switch ((isDayOff, hasStartedDay)) {
      (true, _) => '0:00',
      (false, false) => 'Da iniziare',
      _ => formatSignedHoursInput(todayBalanceMinutes),
    };
    final dayBalanceColor = switch ((isDayOff, hasStartedDay)) {
      (true, _) => colorScheme.primary,
      (false, false) => colorScheme.onSurfaceVariant,
      _ => balanceColor(context, todayBalanceMinutes),
    };
    final overtimeLabel = exceededOvertimeMinutes > 0
        ? 'Oltre straordinario'
        : 'Straordinario';
    final overtimeValue = switch ((isDayOff, hasStartedDay)) {
      (true, _) => '0:00',
      (false, false) => 'Da calcolare',
      _ => formatHoursInput(overtimeMinutes),
    };
    final overtimeColor = switch ((isDayOff, hasStartedDay)) {
      (true, _) => colorScheme.onSurfaceVariant,
      (false, false) => colorScheme.onSurfaceVariant,
      _ =>
        exceededOvertimeMinutes > 0
            ? const Color(0xFF9D3D2F)
            : overtimeMinutes > 0
            ? colorScheme.secondary
            : colorScheme.onSurfaceVariant,
    };
    final overtimeHelperText = exceededOvertimeMinutes > 0
        ? 'Fuori limite di ${formatHoursInput(exceededOvertimeMinutes)}'
        : null;

    return QuickDayHero(
      workedMinutes: workedMinutes,
      isDayOff: isDayOff,
      hasResultContext: hasResultContext,
      dayBalanceLabel: dayBalanceLabel,
      dayBalanceValue: dayBalanceValue,
      dayBalanceColor: dayBalanceColor,
      overtimeLabel: overtimeLabel,
      overtimeValue: overtimeValue,
      overtimeColor: overtimeColor,
      overtimeHelperText: overtimeHelperText,
      showOvertimeConfigurationHint: showOvertimeConfigurationHint,
      overtimeConfigurationHint: overtimeConfigurationHint,
      limitWarningText: limitWarningText,
      onOpenWorkSettings: onOpenWorkSettings,
      monthBalanceInfo: monthBalanceInfo,
      periodBalanceInfo: periodBalanceInfo,
      dayBalanceAggregation: dayBalanceAggregation,
      onDayBalanceAggregationChanged: onDayBalanceAggregationChanged,
      remainingToProgrammedExitLabel: remainingToProgrammedExitLabel,
      expectedMinutes: expectedMinutes,
      unrecordedMinutes: unrecordedMinutes,
      onRegisterUnrecordedHours: onRegisterUnrecordedHours,
    );
  }
}
