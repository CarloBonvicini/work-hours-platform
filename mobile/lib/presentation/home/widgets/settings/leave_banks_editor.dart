// Editor delle banche ore/ferie.

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:work_hours_mobile/application/services/hour_input_parser.dart';
import 'package:work_hours_mobile/domain/models/user_work_rules.dart';
import 'package:work_hours_mobile/presentation/home/logic/rule_value_labels.dart';
import 'package:work_hours_mobile/presentation/home/widgets/settings/permission_rules_editor.dart';

class LeaveBanksEditor extends StatelessWidget {
  const LeaveBanksEditor({
    super.key,
    required this.rules,
    required this.referenceWorkingDayMinutes,
    required this.emptyMessage,
    required this.addButtonLabel,
    required this.onAddRule,
    required this.onEditRule,
    required this.onRemoveRule,
  });

  final List<WorkPermissionRule> rules;
  final int referenceWorkingDayMinutes;
  final String emptyMessage;
  final String addButtonLabel;
  final Future<void> Function() onAddRule;
  final ValueChanged<String> onEditRule;
  final ValueChanged<String> onRemoveRule;

  bool _matchesCategory(WorkPermissionRule rule, List<String> keywords) {
    final normalizedName = rule.name.toLowerCase().trim();
    return keywords.any(normalizedName.contains);
  }

  WorkPermissionRule? _firstRuleByCategory(List<String> keywords) {
    for (final rule in rules) {
      if (_matchesCategory(rule, keywords)) {
        return rule;
      }
    }
    return null;
  }

  int _remainingMinutes(WorkPermissionRule rule) => ruleRemainingMinutes(rule);

  String _formatVacationSummary(WorkPermissionRule? rule) {
    if (rule == null) {
      return 'Non configurate';
    }

    if (rule.allowanceType.includesDays) {
      final remainingDays = ruleRemainingDays(rule);
      if (rule.allowanceType == WorkPermissionAllowanceType.both) {
        return '${formatRuleDaysValue(remainingDays)} + ${formatHoursInput(_remainingMinutes(rule))} disponibili';
      }
      return '${formatRuleDaysValue(remainingDays)} disponibili';
    }

    final remainingMinutes = _remainingMinutes(rule);
    final safeWorkingDayMinutes = math.max(referenceWorkingDayMinutes, 60);
    final remainingDays = remainingMinutes / safeWorkingDayMinutes;
    final isWholeDays = remainingDays == remainingDays.truncateToDouble();
    final formattedDays = isWholeDays
        ? remainingDays.toStringAsFixed(0)
        : remainingDays.toStringAsFixed(1).replaceFirst('.', ',');
    return '$formattedDays giorni disponibili';
  }

  String _formatHoursSummary(WorkPermissionRule? rule) {
    if (rule == null) {
      return 'Non configurati';
    }

    return '${formatRuleRemainingValue(rule)} disponibili';
  }

  String _formatSicknessSummary(WorkPermissionRule? rule) {
    if (rule == null) {
      return 'Non configurata';
    }
    if (!rule.enabled) {
      return 'Disattivata';
    }

    if ((rule.allowanceType.includesHours && rule.allowanceMinutes > 0) ||
        (rule.allowanceType.includesDays && rule.allowanceDays > 0)) {
      return '${formatRuleRemainingValue(rule)} disponibili';
    }

    return 'Senza monte';
  }

  @override
  Widget build(BuildContext context) {
    final ferieRule = _firstRuleByCategory(['ferie', 'vacation']);
    final permitsRule = _firstRuleByCategory(['permess', 'permit']);
    final sicknessRule = _firstRuleByCategory(['malatt', 'sick']);
    final categorizedRuleIds = <String>{
      if (ferieRule != null) ferieRule.id,
      if (permitsRule != null) permitsRule.id,
      if (sicknessRule != null) sicknessRule.id,
    };
    final otherRules = rules
        .where((rule) => !categorizedRuleIds.contains(rule.id))
        .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LeaveBankSummaryTile(
          icon: Icons.beach_access_outlined,
          title: 'Ferie',
          value: _formatVacationSummary(ferieRule),
        ),
        const SizedBox(height: 10),
        LeaveBankSummaryTile(
          icon: Icons.schedule_outlined,
          title: 'Permessi',
          value: _formatHoursSummary(permitsRule),
        ),
        const SizedBox(height: 10),
        LeaveBankSummaryTile(
          icon: Icons.local_hospital_outlined,
          title: 'Malattia',
          value: _formatSicknessSummary(sicknessRule),
        ),
        const SizedBox(height: 12),
        FilledButton.tonalIcon(
          onPressed: () => onAddRule(),
          icon: const Icon(Icons.add_rounded),
          label: Text(addButtonLabel),
        ),
        const SizedBox(height: 12),
        if (rules.isEmpty)
          Text(emptyMessage, style: Theme.of(context).textTheme.bodyMedium)
        else if (otherRules.isNotEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Altre causali',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              Column(
                children: otherRules
                    .map(
                      (rule) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: PermissionRuleTile(
                          rule: rule,
                          onEdit: () => onEditRule(rule.id),
                          onRemove: () => onRemoveRule(rule.id),
                        ),
                      ),
                    )
                    .toList(growable: false),
              ),
            ],
          ),
      ],
    );
  }
}

class LeaveBankSummaryTile extends StatelessWidget {
  const LeaveBankSummaryTile({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
