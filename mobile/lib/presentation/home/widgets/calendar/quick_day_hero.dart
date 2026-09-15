// Riquadro riassuntivo (hero) della giornata nell'editor rapido.

import 'package:flutter/material.dart';
import 'package:work_hours_mobile/application/services/hour_input_parser.dart';
import 'package:work_hours_mobile/application/services/theme_preference_store.dart';
import 'package:work_hours_mobile/presentation/home/logic/quick_day_insights.dart';
import 'package:work_hours_mobile/presentation/home/logic/value_explanations.dart';
import 'package:work_hours_mobile/presentation/home/models/home_section.dart';
import 'package:work_hours_mobile/presentation/home/widgets/calendar/quick_day_period_balance.dart';
import 'package:work_hours_mobile/presentation/home/widgets/common/explainable_value.dart';

class QuickDayHero extends StatelessWidget {
  const QuickDayHero({
    super.key,
    required this.workedMinutes,
    required this.isDayOff,
    required this.hasResultContext,
    required this.dayBalanceLabel,
    required this.dayBalanceValue,
    required this.dayBalanceColor,
    required this.overtimeLabel,
    required this.overtimeValue,
    required this.overtimeColor,
    required this.overtimeHelperText,
    required this.limitWarningText,
    required this.showOvertimeConfigurationHint,
    required this.overtimeConfigurationHint,
    required this.onOpenWorkSettings,
    required this.monthBalanceInfo,
    required this.periodBalanceInfo,
    required this.dayBalanceAggregation,
    required this.onDayBalanceAggregationChanged,
    required this.remainingToProgrammedExitLabel,
    required this.expectedMinutes,
    required this.unrecordedMinutes,
    required this.onRegisterUnrecordedHours,
    required this.onOpenSettingsSection,
  });

  final int workedMinutes;
  final bool isDayOff;
  final bool hasResultContext;
  final String dayBalanceLabel;
  final String dayBalanceValue;
  final Color dayBalanceColor;
  final String overtimeLabel;
  final String overtimeValue;
  final Color overtimeColor;
  final String? overtimeHelperText;
  final String? limitWarningText;
  final bool showOvertimeConfigurationHint;
  final String? overtimeConfigurationHint;
  final VoidCallback onOpenWorkSettings;
  final DisplayedMonthBalanceInfo monthBalanceInfo;
  final DisplayedPeriodBalanceInfo periodBalanceInfo;
  final DayBalanceAggregation dayBalanceAggregation;
  final ValueChanged<DayBalanceAggregation> onDayBalanceAggregationChanged;
  final String? remainingToProgrammedExitLabel;
  final int expectedMinutes;
  final int? unrecordedMinutes;
  final VoidCallback? onRegisterUnrecordedHours;
  final void Function(HomeSection section) onOpenSettingsSection;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final labelStyle = theme.textTheme.labelMedium?.copyWith(
      color: colorScheme.onSurfaceVariant.withValues(alpha: 0.72),
      fontWeight: FontWeight.w700,
      letterSpacing: 0.2,
    );
    final secondaryValueStyle = theme.textTheme.titleLarge?.copyWith(
      fontSize: 18,
      height: 1.05,
      color: colorScheme.onSurface,
      fontWeight: FontWeight.w800,
    );
    final helperStyle = theme.textTheme.bodySmall?.copyWith(
      color: colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w600,
      fontSize: 11.5,
      height: 1.15,
    );
    final unrecorded = unrecordedMinutes;
    final workedHelperText = switch ((isDayOff, hasResultContext)) {
      (true, _) => 'Nessuna ora da registrare',
      // L'orario del giorno c'e' ma le ore non sono mai state registrate: dirlo
      // e' l'unico modo perche' uno 0:00 con entrata e uscita a video si capisca.
      (false, false) when unrecorded != null =>
        'Orario presente, ore mai registrate: '
            '${formatHoursInput(unrecorded)} da registrare',
      (false, false) => 'Inserisci l\'entrata per iniziare',
      _ => remainingToProgrammedExitLabel,
    };
    final hasRemainingToProgrammedExit =
        remainingToProgrammedExitLabel != null && !isDayOff && hasResultContext;
    // Ore fatte su ore da fare oggi. Prima il secondo numero sommava ore
    // lavorate e minuti di orologio mancanti: due grandezze diverse, un
    // risultato che non voleva dire niente.
    final workedValue = expectedMinutes <= 0 || !hasResultContext || isDayOff
        ? formatHoursInput(workedMinutes)
        : '${formatHoursInput(workedMinutes)}/${formatHoursInput(expectedMinutes)}';
    final neutralValueColor = colorScheme.onSurfaceVariant;
    Widget explain(ExplainableValue value, Widget child) {
      return ExplainableValueBox(
        value: value,
        onOpenSettings: onOpenSettingsSection,
        child: child,
      );
    }

    Widget metricBlock({
      required String label,
      required String value,
      required Key valueKey,
      required Color valueColor,
      String? helperText,
    }) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExplainableLabel(label: label, style: labelStyle),
          const SizedBox(height: 4),
          Text(
            value,
            key: valueKey,
            style: secondaryValueStyle?.copyWith(color: valueColor),
          ),
          if (helperText != null) ...[
            const SizedBox(height: 2),
            Text(helperText, style: helperStyle),
          ],
        ],
      );
    }

    final workedBlock = explain(
      ExplainableValue.worked,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExplainableLabel(label: 'Lavorate', style: labelStyle),
          const SizedBox(height: 4),
          Text(
            workedValue,
            key: const ValueKey('calendar-live-worked-value'),
            style: theme.textTheme.headlineLarge?.copyWith(
              fontSize: 30,
              height: 1,
              fontWeight: FontWeight.w900,
              color: colorScheme.primary,
            ),
          ),
          if (workedHelperText != null) ...[
            const SizedBox(height: 2),
            Text(
              workedHelperText,
              style: helperStyle?.copyWith(
                color: hasRemainingToProgrammedExit
                    ? colorScheme.secondary
                    : helperStyle.color,
                fontWeight: hasRemainingToProgrammedExit
                    ? FontWeight.w700
                    : helperStyle.fontWeight,
              ),
            ),
          ],
          if (unrecorded != null && onRegisterUnrecordedHours != null) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              key: const ValueKey('calendar-register-unrecorded-hours-button'),
              onPressed: onRegisterUnrecordedHours,
              icon: const Icon(Icons.playlist_add_check_rounded, size: 18),
              label: Text('Registra ${formatHoursInput(unrecorded)}'),
            ),
          ],
        ],
      ),
    );
    final balanceBlock = explain(
      ExplainableValue.dayBalance,
      metricBlock(
        label: dayBalanceLabel,
        value: dayBalanceValue,
        valueKey: const ValueKey('calendar-live-day-balance-value'),
        valueColor: hasResultContext || isDayOff
            ? dayBalanceColor
            : neutralValueColor,
      ),
    );
    final overtimeBlock = explain(
      ExplainableValue.overtime,
      metricBlock(
        label: overtimeLabel,
        value: overtimeValue,
        valueKey: const ValueKey('calendar-live-overtime-value'),
        valueColor: overtimeColor,
        helperText: overtimeHelperText,
      ),
    );
    final monthBlock = explain(
      ExplainableValue.monthBalance,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExplainableLabel(label: 'Saldo mese', style: labelStyle),
          const SizedBox(height: 3),
          Text(
            monthBalanceInfo.value,
            key: const ValueKey('calendar-live-month-balance-value'),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: secondaryValueStyle?.copyWith(
              fontSize: 16,
              color: colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
    final periodBalanceBlock = explain(
      ExplainableValue.periodBalance,
      QuickDayPeriodBalance(
        info: periodBalanceInfo,
        aggregation: dayBalanceAggregation,
        onAggregationChanged: onDayBalanceAggregationChanged,
        labelStyle: labelStyle,
        valueStyle: secondaryValueStyle,
        neutralColor: neutralValueColor,
      ),
    );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Color.lerp(
          colorScheme.surfaceContainerLow,
          colorScheme.primary,
          0.05,
        )!,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.82),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth >= 300) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 4, child: workedBlock),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          balanceBlock,
                          const SizedBox(height: 10),
                          overtimeBlock,
                        ],
                      ),
                    ),
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  workedBlock,
                  const SizedBox(height: 12),
                  balanceBlock,
                  const SizedBox(height: 10),
                  overtimeBlock,
                ],
              );
            },
          ),
          if (showOvertimeConfigurationHint) ...[
            const SizedBox(height: 10),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  overtimeConfigurationHint ??
                      'Per attivare limiti credito/straordinario ',
                  style: helperStyle,
                ),
                GestureDetector(
                  onTap: onOpenWorkSettings,
                  child: Text(
                    'clicca qui',
                    style: helperStyle?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w800,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
                Text('.', style: helperStyle),
              ],
            ),
          ],
          if (limitWarningText != null) ...[
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  size: 16,
                  color: const Color(0xFF9D3D2F),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    limitWarningText!,
                    style: helperStyle?.copyWith(
                      color: const Color(0xFF9D3D2F),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          Divider(
            height: 1,
            color: colorScheme.outlineVariant.withValues(alpha: 0.24),
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth >= 280) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: periodBalanceBlock),
                    const SizedBox(width: 10),
                    Expanded(child: monthBlock),
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  periodBalanceBlock,
                  const SizedBox(height: 10),
                  monthBlock,
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
