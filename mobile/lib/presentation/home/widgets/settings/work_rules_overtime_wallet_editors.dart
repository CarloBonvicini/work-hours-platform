// Editor di straordinario e borsellino.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:work_hours_mobile/presentation/home/logic/rule_value_labels.dart';
import 'package:work_hours_mobile/presentation/home/widgets/settings/settings_section_panel.dart';

class WorkRulesOvertimeEditor extends StatelessWidget {
  const WorkRulesOvertimeEditor({
    super.key,
    required this.overtimeEnabled,
    required this.overtimeCapEnabled,
    required this.overtimeDailyCapText,
    required this.overtimeWeeklyCapText,
    required this.overtimeMonthlyCapText,
    required this.onOvertimeEnabledChanged,
    required this.onOvertimeCapEnabledChanged,
    required this.onPickDailyCap,
    required this.onPickWeeklyCap,
    required this.onPickMonthlyCap,
  });

  final bool overtimeEnabled;
  final bool overtimeCapEnabled;
  final String overtimeDailyCapText;
  final String overtimeWeeklyCapText;
  final String overtimeMonthlyCapText;
  final ValueChanged<bool> onOvertimeEnabledChanged;
  final ValueChanged<bool> onOvertimeCapEnabledChanged;
  final Future<void> Function() onPickDailyCap;
  final Future<void> Function() onPickWeeklyCap;
  final Future<void> Function() onPickMonthlyCap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          value: overtimeEnabled,
          onChanged: onOvertimeEnabledChanged,
          title: const Text('Straordinario abilitato'),
          subtitle: const Text(
            'Se disattivo, il credito extra viene bloccato o limitato da altre regole.',
          ),
        ),
        if (overtimeEnabled) ...[
          const SizedBox(height: 6),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: overtimeCapEnabled,
            onChanged: onOvertimeCapEnabledChanged,
            title: const Text('Massimale straordinario attivo'),
            subtitle: const Text(
              'Puoi limitare il massimo accumulabile su giorno, settimana e mese.',
            ),
          ),
          if (overtimeCapEnabled) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                SlimSettingsScheduleValue(
                  label: 'Max giorno',
                  value: formatOptionalHoursValue(
                    overtimeDailyCapText,
                    zeroLabel: 'Nessun limite',
                  ),
                  icon: Icons.calendar_today_outlined,
                  kind: SettingsValueKind.limit,
                  onTap: onPickDailyCap,
                ),
                SlimSettingsScheduleValue(
                  label: 'Max settimana',
                  value: formatOptionalHoursValue(
                    overtimeWeeklyCapText,
                    zeroLabel: 'Nessun limite',
                  ),
                  icon: Icons.date_range_rounded,
                  kind: SettingsValueKind.limit,
                  onTap: onPickWeeklyCap,
                ),
                SlimSettingsScheduleValue(
                  label: 'Max mese',
                  value: formatOptionalHoursValue(
                    overtimeMonthlyCapText,
                    zeroLabel: 'Nessun limite',
                  ),
                  icon: Icons.calendar_month_outlined,
                  kind: SettingsValueKind.limit,
                  onTap: onPickMonthlyCap,
                ),
              ],
            ),
          ],
        ] else ...[
          const SizedBox(height: 8),
          Text(
            'Nessun credito straordinario viene conteggiato.',
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ],
    );
  }
}

class WorkRulesWalletEditor extends StatelessWidget {
  const WorkRulesWalletEditor({
    super.key,
    required this.walletEnabled,
    required this.walletDailyExitText,
    required this.walletWeeklyExitText,
    required this.implicitCreditEnabled,
    required this.implicitCreditDailyCapText,
    required this.onWalletEnabledChanged,
    required this.onImplicitCreditEnabledChanged,
    required this.onPickWalletDailyExit,
    required this.onPickWalletWeeklyExit,
    required this.onPickImplicitCreditDailyCap,
  });

  final bool walletEnabled;
  final String walletDailyExitText;
  final String walletWeeklyExitText;
  final bool implicitCreditEnabled;
  final String implicitCreditDailyCapText;
  final ValueChanged<bool> onWalletEnabledChanged;
  final ValueChanged<bool> onImplicitCreditEnabledChanged;
  final Future<void> Function() onPickWalletDailyExit;
  final Future<void> Function() onPickWalletWeeklyExit;
  final Future<void> Function() onPickImplicitCreditDailyCap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          value: walletEnabled,
          onChanged: onWalletEnabledChanged,
          title: const Text('Permesso uscita anticipata con limite'),
          subtitle: const Text(
            'Permette di uscire prima entro i limiti giornalieri e settimanali.',
          ),
        ),
        if (walletEnabled) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              SlimSettingsScheduleValue(
                label: 'Max giorno',
                value: formatOptionalHoursValue(
                  walletDailyExitText,
                  zeroLabel: 'Nessun limite',
                ),
                icon: Icons.today_outlined,
                kind: SettingsValueKind.limit,
                onTap: onPickWalletDailyExit,
              ),
              SlimSettingsScheduleValue(
                label: 'Max settimana',
                value: formatOptionalHoursValue(
                  walletWeeklyExitText,
                  zeroLabel: 'Nessun limite',
                ),
                icon: Icons.view_week_outlined,
                kind: SettingsValueKind.limit,
                onTap: onPickWalletWeeklyExit,
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        const Divider(),
        const SizedBox(height: 4),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          value: implicitCreditEnabled,
          onChanged: onImplicitCreditEnabledChanged,
          title: const Text('Credito extra senza straordinario'),
          subtitle: const Text(
            'Limita il credito maturabile se resti oltre l orario standard.',
          ),
        ),
        if (implicitCreditEnabled) ...[
          const SizedBox(height: 10),
          SlimSettingsScheduleValue(
            label: 'Max credito giorno',
            value: formatOptionalHoursValue(
              implicitCreditDailyCapText,
              zeroLabel: 'Nessun credito',
            ),
            icon: Icons.trending_up_rounded,
            kind: SettingsValueKind.limit,
            onTap: onPickImplicitCreditDailyCap,
          ),
        ],
      ],
    );
  }
}
