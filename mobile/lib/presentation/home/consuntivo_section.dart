import 'package:flutter/material.dart';

enum ConsuntivoRangeOption { oneMonth, threeMonths, twelveMonths }

extension ConsuntivoRangeOptionX on ConsuntivoRangeOption {
  int get monthCount {
    switch (this) {
      case ConsuntivoRangeOption.oneMonth:
        return 1;
      case ConsuntivoRangeOption.threeMonths:
        return 3;
      case ConsuntivoRangeOption.twelveMonths:
        return 12;
    }
  }

  String get label {
    switch (this) {
      case ConsuntivoRangeOption.oneMonth:
        return '1 mese';
      case ConsuntivoRangeOption.threeMonths:
        return '3 mesi';
      case ConsuntivoRangeOption.twelveMonths:
        return '12 mesi';
    }
  }
}

class ConsuntivoSectionData {
  const ConsuntivoSectionData({
    required this.anchorMonthLabel,
    required this.periodLabel,
    required this.totals,
    required this.months,
    required this.permissions,
    required this.days,
    required this.hiddenDaysCount,
  });

  final String anchorMonthLabel;
  final String periodLabel;
  final ConsuntivoTotals totals;
  final List<ConsuntivoMonthSummary> months;
  final List<ConsuntivoPermissionSummary> permissions;
  final List<ConsuntivoDaySummary> days;
  final int hiddenDaysCount;
}

class ConsuntivoTotals {
  const ConsuntivoTotals({
    required this.expectedMinutes,
    required this.workedMinutes,
    required this.leaveMinutes,
    required this.rawBalanceMinutes,
    required this.clampedBalanceMinutes,
    required this.overtimeMaturedMinutes,
    required this.debitMaturedMinutes,
  });

  final int expectedMinutes;
  final int workedMinutes;
  final int leaveMinutes;
  final int rawBalanceMinutes;
  final int clampedBalanceMinutes;
  final int overtimeMaturedMinutes;
  final int debitMaturedMinutes;
}

class ConsuntivoMonthSummary {
  const ConsuntivoMonthSummary({
    required this.monthLabel,
    required this.expectedMinutes,
    required this.workedMinutes,
    required this.leaveMinutes,
    required this.balanceMinutes,
  });

  final String monthLabel;
  final int expectedMinutes;
  final int workedMinutes;
  final int leaveMinutes;
  final int balanceMinutes;
}

class ConsuntivoPermissionSummary {
  const ConsuntivoPermissionSummary({
    required this.name,
    required this.periodLabel,
    required this.enabled,
    required this.allowanceLabel,
    required this.usedLabel,
    required this.remainingLabel,
    required this.movementsLabel,
  });

  final String name;
  final String periodLabel;
  final bool enabled;
  final String allowanceLabel;
  final String usedLabel;
  final String remainingLabel;
  final String movementsLabel;
}

class ConsuntivoDaySummary {
  const ConsuntivoDaySummary({
    required this.dateLabel,
    required this.plannedLabel,
    required this.registeredLabel,
    required this.balanceMinutes,
    this.scheduleDetail,
    this.causalDetail,
  });

  final String dateLabel;
  final String plannedLabel;
  final String registeredLabel;
  final int balanceMinutes;
  final String? scheduleDetail;
  final String? causalDetail;
}

class ConsuntivoSection extends StatelessWidget {
  const ConsuntivoSection({
    super.key,
    required this.data,
    required this.selectedRange,
    required this.isLoading,
    required this.onRangeChanged,
    required this.onPreviousMonth,
    required this.onNextMonth,
  });

  final ConsuntivoSectionData data;
  final ConsuntivoRangeOption selectedRange;
  final bool isLoading;
  final ValueChanged<ConsuntivoRangeOption> onRangeChanged;
  final Future<void> Function() onPreviousMonth;
  final Future<void> Function() onNextMonth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      key: const ValueKey('home-section-consuntivo'),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Consuntivo',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Periodo: ${data.periodLabel}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                IconButton.filledTonal(
                  key: const ValueKey('consuntivo-month-prev'),
                  onPressed: isLoading ? null : () => onPreviousMonth(),
                  icon: const Icon(Icons.chevron_left),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    data.anchorMonthLabel,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton.filledTonal(
                  key: const ValueKey('consuntivo-month-next'),
                  onPressed: isLoading ? null : () => onNextMonth(),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SegmentedButton<ConsuntivoRangeOption>(
              key: const ValueKey('consuntivo-range-selector'),
              segments: [
                for (final option in ConsuntivoRangeOption.values)
                  ButtonSegment<ConsuntivoRangeOption>(
                    value: option,
                    label: Text(option.label),
                  ),
              ],
              selected: {selectedRange},
              onSelectionChanged: (selection) {
                if (selection.isNotEmpty) {
                  onRangeChanged(selection.first);
                }
              },
            ),
            if (isLoading) ...[
              const SizedBox(height: 10),
              const LinearProgressIndicator(minHeight: 3),
            ],
            const SizedBox(height: 16),
            _MetricGrid(totals: data.totals),
            const SizedBox(height: 18),
            Text(
              'Mesi inclusi',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: data.months
                  .map((month) {
                    final balanceColor = _balanceColor(
                      theme,
                      month.balanceMinutes,
                    );
                    return Container(
                      width: 180,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: colorScheme.surfaceContainerLow,
                        border: Border.all(color: colorScheme.outlineVariant),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            month.monthLabel,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Programmate ${_formatHours(month.expectedMinutes)}',
                          ),
                          Text(
                            'Registrate ${_formatHours(month.workedMinutes)}',
                          ),
                          Text('Causali ${_formatHours(month.leaveMinutes)}'),
                          const SizedBox(height: 6),
                          Text(
                            'Saldo ${_formatSignedHours(month.balanceMinutes)}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: balanceColor,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    );
                  })
                  .toList(growable: false),
            ),
            const SizedBox(height: 18),
            Text(
              'Permessi e causali',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            if (data.permissions.isEmpty)
              Text(
                'Nessuna regola permesso configurata.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              )
            else
              Column(
                children: data.permissions
                    .map((permission) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: colorScheme.outlineVariant,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      permission.name,
                                      style: theme.textTheme.titleSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                  ),
                                  Text(
                                    permission.enabled
                                        ? 'Attivo'
                                        : 'Disattivato',
                                    style: theme.textTheme.labelMedium
                                        ?.copyWith(
                                          color: permission.enabled
                                              ? const Color(0xFF0B6E69)
                                              : colorScheme.onSurfaceVariant,
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${permission.periodLabel} - Disponibili ${permission.remainingLabel} su ${permission.allowanceLabel}',
                              ),
                              Text('Usate ${permission.usedLabel}'),
                              Text(
                                permission.movementsLabel,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    })
                    .toList(growable: false),
              ),
            const SizedBox(height: 8),
            Text(
              'Dettaglio giorni',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            if (data.days.isEmpty)
              Text(
                'Nessuna attivita trovata nel periodo selezionato.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              )
            else
              Column(
                children: data.days
                    .map((day) {
                      final balanceColor = _balanceColor(
                        theme,
                        day.balanceMinutes,
                      );
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          tileColor: colorScheme.surfaceContainerLowest,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: BorderSide(color: colorScheme.outlineVariant),
                          ),
                          title: Text(day.dateLabel),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Programmato ${day.plannedLabel} | Registrato ${day.registeredLabel}',
                              ),
                              if (day.scheduleDetail != null)
                                Text(day.scheduleDetail!),
                              if (day.causalDetail != null)
                                Text(day.causalDetail!),
                            ],
                          ),
                          trailing: Text(
                            _formatSignedHours(day.balanceMinutes),
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: balanceColor,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      );
                    })
                    .toList(growable: false),
              ),
            if (data.hiddenDaysCount > 0)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  'Mostrati ${data.days.length} giorni, altri ${data.hiddenDaysCount} non mostrati.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _balanceColor(ThemeData theme, int value) {
    if (value > 0) {
      return const Color(0xFF0B6E69);
    }
    if (value < 0) {
      return const Color(0xFFB42318);
    }
    return theme.colorScheme.onSurfaceVariant;
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.totals});

  final ConsuntivoTotals totals;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _MetricTile(
          label: 'Programmate',
          value: _formatHours(totals.expectedMinutes),
        ),
        _MetricTile(
          label: 'Lavorate',
          value: _formatHours(totals.workedMinutes),
        ),
        _MetricTile(label: 'Causali', value: _formatHours(totals.leaveMinutes)),
        _MetricTile(
          label: 'Saldo reale',
          value: _formatSignedHours(totals.rawBalanceMinutes),
        ),
        _MetricTile(
          label: 'Saldo controllato',
          value: _formatSignedHours(totals.clampedBalanceMinutes),
        ),
        _MetricTile(
          label: 'Straordinario maturato',
          value: _formatHours(totals.overtimeMaturedMinutes),
          positive: true,
        ),
        _MetricTile(
          label: 'Debito maturato',
          value: _formatHours(totals.debitMaturedMinutes),
        ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    this.positive = false,
  });

  final String label;
  final String value;
  final bool positive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 160,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: theme.colorScheme.surfaceContainerLow,
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.labelMedium),
          const SizedBox(height: 6),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: positive ? const Color(0xFF0B6E69) : null,
            ),
          ),
        ],
      ),
    );
  }
}

String _formatHours(int minutes) {
  final absoluteMinutes = minutes.abs();
  final hours = absoluteMinutes ~/ 60;
  final remainingMinutes = absoluteMinutes % 60;
  final prefix = minutes < 0 ? '-' : '';
  return '$prefix$hours:${remainingMinutes.toString().padLeft(2, '0')}';
}

String _formatSignedHours(int minutes) {
  if (minutes == 0) {
    return '0:00';
  }
  final prefix = minutes > 0 ? '+' : '-';
  return '$prefix${_formatHours(minutes.abs())}';
}
