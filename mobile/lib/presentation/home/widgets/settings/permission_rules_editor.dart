// Editor delle regole permessi aggiuntivi.

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:work_hours_mobile/application/services/hour_input_parser.dart';
import 'package:work_hours_mobile/domain/models/user_work_rules.dart';
import 'package:work_hours_mobile/presentation/home/logic/rule_value_labels.dart';

class PermissionRulesEditor extends StatelessWidget {
  const PermissionRulesEditor({
    super.key,
    required this.rules,
    required this.emptyMessage,
    required this.addButtonLabel,
    required this.onAddRule,
    required this.onEditRule,
    required this.onRemoveRule,
  });

  final List<WorkPermissionRule> rules;
  final String emptyMessage;
  final String addButtonLabel;
  final Future<void> Function() onAddRule;
  final ValueChanged<String> onEditRule;
  final ValueChanged<String> onRemoveRule;

  @override
  Widget build(BuildContext context) {
    final activeRules = rules.where((rule) => rule.enabled).length;
    final hourRules = rules.where((rule) => rule.allowanceType.includesHours);
    final dayRules = rules.where((rule) => rule.allowanceType.includesDays);
    final totalAllowanceMinutes = rules.fold<int>(
      0,
      (sum, rule) =>
          sum + (rule.allowanceType.includesHours ? rule.allowanceMinutes : 0),
    );
    final totalUsedMinutes = rules.fold<int>(
      0,
      (sum, rule) =>
          sum +
          (rule.allowanceType.includesHours ? ruleSafeUsedMinutes(rule) : 0),
    );
    final remainingMinutes = math.max(
      totalAllowanceMinutes - totalUsedMinutes,
      0,
    );
    final totalAllowanceDays = rules.fold<int>(
      0,
      (sum, rule) =>
          sum + (rule.allowanceType.includesDays ? rule.allowanceDays : 0),
    );
    final totalUsedDays = rules.fold<int>(
      0,
      (sum, rule) =>
          sum + (rule.allowanceType.includesDays ? ruleSafeUsedDays(rule) : 0),
    );
    final remainingDays = math.max(totalAllowanceDays - totalUsedDays, 0);
    final configuredMovements = {
      for (final rule in rules)
        ...rule.movements.map((movement) => movement.label),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (rules.isNotEmpty) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Monitoraggio impostazioni',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    PermissionRuleMonitorChip(
                      label: 'Configurati',
                      value: rules.length.toString(),
                    ),
                    PermissionRuleMonitorChip(
                      label: 'Attivi',
                      value: activeRules.toString(),
                    ),
                    if (hourRules.isNotEmpty) ...[
                      PermissionRuleMonitorChip(
                        label: 'Regole ore',
                        value: hourRules.length.toString(),
                      ),
                      PermissionRuleMonitorChip(
                        label: 'Monte ore',
                        value: formatHoursInput(totalAllowanceMinutes),
                      ),
                      PermissionRuleMonitorChip(
                        label: 'Usate ore',
                        value: formatHoursInput(totalUsedMinutes),
                      ),
                      PermissionRuleMonitorChip(
                        label: 'Residuo ore',
                        value: formatHoursInput(remainingMinutes),
                      ),
                    ],
                    if (dayRules.isNotEmpty) ...[
                      PermissionRuleMonitorChip(
                        label: 'Regole giorni',
                        value: dayRules.length.toString(),
                      ),
                      PermissionRuleMonitorChip(
                        label: 'Monte giorni',
                        value: formatRuleDaysValue(totalAllowanceDays),
                      ),
                      PermissionRuleMonitorChip(
                        label: 'Usati giorni',
                        value: formatRuleDaysValue(totalUsedDays),
                      ),
                      PermissionRuleMonitorChip(
                        label: 'Residuo giorni',
                        value: formatRuleDaysValue(remainingDays),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  configuredMovements.isEmpty
                      ? 'Movimenti configurati: nessuno'
                      : 'Movimenti configurati: ${configuredMovements.join(', ')}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        FilledButton.tonalIcon(
          onPressed: () => onAddRule(),
          icon: const Icon(Icons.add_rounded),
          label: Text(addButtonLabel),
        ),
        const SizedBox(height: 12),
        if (rules.isEmpty)
          Text(emptyMessage, style: Theme.of(context).textTheme.bodyMedium)
        else
          Column(
            children: rules
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
    );
  }
}

class PermissionRuleTile extends StatelessWidget {
  const PermissionRuleTile({
    super.key,
    required this.rule,
    required this.onEdit,
    required this.onRemove,
  });

  final WorkPermissionRule rule;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final movementLabels = rule.movements
        .map((movement) => movement.label)
        .join(', ');

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  rule.name,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Chip(
                label: Text(rule.enabled ? 'Attivo' : 'Disattivato'),
                visualDensity: VisualDensity.compact,
              ),
              IconButton(
                onPressed: onEdit,
                tooltip: 'Modifica ${rule.name}',
                icon: const Icon(Icons.edit_outlined),
              ),
              IconButton(
                onPressed: onRemove,
                tooltip: 'Rimuovi ${rule.name}',
                icon: const Icon(Icons.delete_outline_rounded),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${rule.period.label} - ${formatRuleAvailabilitySummary(rule)}',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Utilizzate ${formatRuleUsedValue(rule)} - $movementLabels',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class PermissionRuleMonitorChip extends StatelessWidget {
  const PermissionRuleMonitorChip({
    super.key,
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Text(
        '$label: $value',
        style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}
