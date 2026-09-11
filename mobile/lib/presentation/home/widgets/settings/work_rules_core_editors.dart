// Editor delle regole base, limiti e presenza.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:work_hours_mobile/domain/models/user_work_rules.dart';
import 'package:work_hours_mobile/presentation/home/logic/rule_value_labels.dart';
import 'package:work_hours_mobile/presentation/home/widgets/settings/settings_section_panel.dart';

class WorkRulesCoreEditor extends StatelessWidget {
  const WorkRulesCoreEditor({
    super.key,
    required this.minimumBreakText,
    required this.pauseAdjustmentMode,
    required this.onPauseAdjustmentModeChanged,
    required this.isBusy,
    required this.onPickMinimumBreak,
  });

  final String minimumBreakText;
  final WorkRulesPauseAdjustmentMode pauseAdjustmentMode;
  final ValueChanged<WorkRulesPauseAdjustmentMode> onPauseAdjustmentModeChanged;
  final bool isBusy;
  final Future<void> Function() onPickMinimumBreak;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SlimSettingsScheduleValue(
          label: 'Pausa minima',
          value: formatSettingsBreakValue(
            minimumBreakText,
            isMinimumBreak: true,
          ),
          icon: Icons.free_breakfast_outlined,
          kind: SettingsValueKind.duration,
          onTap: onPickMinimumBreak,
        ),
        const SizedBox(height: 12),
        Text(
          'Quando cambi la pausa in Oggi',
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            ChoiceChip(
              label: const Text('Ore lavorate fisse'),
              selected:
                  pauseAdjustmentMode ==
                  WorkRulesPauseAdjustmentMode.keepWorkedMinutes,
              onSelected: isBusy
                  ? null
                  : (_) => onPauseAdjustmentModeChanged(
                      WorkRulesPauseAdjustmentMode.keepWorkedMinutes,
                    ),
            ),
            ChoiceChip(
              label: const Text('Uscita fissa'),
              selected:
                  pauseAdjustmentMode ==
                  WorkRulesPauseAdjustmentMode.keepEndTime,
              onSelected: isBusy
                  ? null
                  : (_) => onPauseAdjustmentModeChanged(
                      WorkRulesPauseAdjustmentMode.keepEndTime,
                    ),
            ),
          ],
        ),
      ],
    );
  }
}

class WorkRulesLimitsEditor extends StatelessWidget {
  const WorkRulesLimitsEditor({
    super.key,
    required this.maximumDailyCreditText,
    required this.maximumDailyDebitText,
    required this.maximumMonthlyCreditText,
    required this.maximumMonthlyDebitText,
    required this.onPickMaximumDailyCredit,
    required this.onPickMaximumDailyDebit,
    required this.onPickMaximumMonthlyCredit,
    required this.onPickMaximumMonthlyDebit,
  });

  final String maximumDailyCreditText;
  final String maximumDailyDebitText;
  final String maximumMonthlyCreditText;
  final String maximumMonthlyDebitText;
  final Future<void> Function() onPickMaximumDailyCredit;
  final Future<void> Function() onPickMaximumDailyDebit;
  final Future<void> Function() onPickMaximumMonthlyCredit;
  final Future<void> Function() onPickMaximumMonthlyDebit;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        SlimSettingsScheduleValue(
          label: 'Max credito giorno',
          value: formatSettingsLimitValue(
            maximumDailyCreditText,
            unboundedMinutes: 24 * 60,
          ),
          icon: Icons.trending_up_rounded,
          kind: SettingsValueKind.limit,
          onTap: onPickMaximumDailyCredit,
        ),
        SlimSettingsScheduleValue(
          label: 'Max debito giorno',
          value: formatSettingsLimitValue(
            maximumDailyDebitText,
            unboundedMinutes: 24 * 60,
          ),
          icon: Icons.trending_down_rounded,
          kind: SettingsValueKind.limit,
          onTap: onPickMaximumDailyDebit,
        ),
        SlimSettingsScheduleValue(
          label: 'Max credito mese',
          value: formatSettingsLimitValue(
            maximumMonthlyCreditText,
            unboundedMinutes: 31 * 24 * 60,
          ),
          icon: Icons.calendar_month_outlined,
          kind: SettingsValueKind.limit,
          onTap: onPickMaximumMonthlyCredit,
        ),
        SlimSettingsScheduleValue(
          label: 'Max debito mese',
          value: formatSettingsLimitValue(
            maximumMonthlyDebitText,
            unboundedMinutes: 31 * 24 * 60,
          ),
          icon: Icons.event_note_outlined,
          kind: SettingsValueKind.limit,
          onTap: onPickMaximumMonthlyDebit,
        ),
      ],
    );
  }
}

class WorkRulesAttendanceEditor extends StatelessWidget {
  const WorkRulesAttendanceEditor({
    super.key,
    required this.fixedScheduleEnabled,
    required this.flexibleStartEnabled,
    required this.flexibleStartWindowText,
    required this.flexibleStartRangeHints,
    required this.onFixedScheduleChanged,
    required this.onFlexibleStartChanged,
    required this.onPickFlexibleStartWindow,
  });

  final bool fixedScheduleEnabled;
  final bool flexibleStartEnabled;
  final String flexibleStartWindowText;
  final List<String> flexibleStartRangeHints;
  final ValueChanged<bool> onFixedScheduleChanged;
  final ValueChanged<bool> onFlexibleStartChanged;
  final Future<void> Function() onPickFlexibleStartWindow;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final showRangeHints = flexibleStartRangeHints.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          value: fixedScheduleEnabled,
          onChanged: onFixedScheduleChanged,
          title: const Text('Uso un orario fisso di entrata'),
          subtitle: const Text(
            'Serve come base per calcolare la fascia di ingresso consentita.',
          ),
        ),
        const SizedBox(height: 6),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          value: flexibleStartEnabled,
          onChanged: onFlexibleStartChanged,
          title: const Text('Flessibilita in entrata'),
          subtitle: const Text(
            'Imposti solo il ritardo massimo dall entrata fissa (esempio: 07:30 + 2:00 = 07:30-09:30).',
          ),
        ),
        if (flexibleStartEnabled) ...[
          const SizedBox(height: 10),
          SlimSettingsScheduleValue(
            label: 'Ritardo massimo consentito',
            value: formatOptionalHoursValue(
              flexibleStartWindowText,
              zeroLabel: 'Nessuna flessibilita',
            ),
            icon: Icons.access_time_rounded,
            kind: SettingsValueKind.duration,
            onTap: onPickFlexibleStartWindow,
          ),
          const SizedBox(height: 10),
          Text(
            'Fascia di ingresso calcolata',
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          if (showRangeHints)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final hint in flexibleStartRangeHints)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant,
                      ),
                    ),
                    child: Text(
                      hint,
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            )
          else
            Text(
              fixedScheduleEnabled
                  ? 'Imposta Entrata in Orario di lavoro per vedere l intervallo.'
                  : 'Attiva l ingresso fisso e imposta Entrata in Orario di lavoro.',
              style: theme.textTheme.bodyMedium,
            ),
        ],
      ],
    );
  }
}
