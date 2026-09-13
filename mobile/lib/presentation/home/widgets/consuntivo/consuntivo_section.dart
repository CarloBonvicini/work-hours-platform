// Sezione consuntivo: riepilogo del periodo ed esportazione.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:work_hours_mobile/presentation/home/logic/consuntivo_export.dart';
import 'package:work_hours_mobile/presentation/home/widgets/consuntivo/consuntivo_metrics.dart';
import 'package:work_hours_mobile/presentation/home/models/consuntivo_summary.dart';

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
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                OutlinedButton.icon(
                  key: const ValueKey('consuntivo-export-pdf'),
                  onPressed: isLoading ? null : () => _exportPdf(context),
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: const Text('Esporta PDF'),
                ),
                OutlinedButton.icon(
                  key: const ValueKey('consuntivo-export-csv'),
                  onPressed: isLoading ? null : () => _exportCsv(context),
                  icon: const Icon(Icons.table_view_outlined),
                  label: const Text('Esporta CSV'),
                ),
              ],
            ),
            if (isLoading) ...[
              const SizedBox(height: 10),
              const LinearProgressIndicator(minHeight: 3),
            ],
            const SizedBox(height: 16),
            ConsuntivoMetricGrid(totals: data.totals),
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
                            'Programmate ${formatConsuntivoMetricHours(month.expectedMinutes)}',
                          ),
                          Text(
                            'Registrate ${formatConsuntivoMetricHours(month.workedMinutes)}',
                          ),
                          Text(
                            'Causali ${formatConsuntivoMetricHours(month.leaveMinutes)}',
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Saldo ${formatConsuntivoMetricSignedHours(month.balanceMinutes)}',
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
                            formatConsuntivoMetricSignedHours(
                              day.balanceMinutes,
                            ),
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

  String _exportFileBaseName() {
    final normalizedPeriod = data.periodLabel
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    return normalizedPeriod.isEmpty
        ? 'consuntivo'
        : 'consuntivo-$normalizedPeriod';
  }

  Future<void> _exportPdf(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final pdfBytes = await buildConsuntivoPdf(data);
      await Printing.sharePdf(
        bytes: pdfBytes,
        filename: '${_exportFileBaseName()}.pdf',
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Export PDF non riuscito su questo dispositivo.'),
        ),
      );
    }
  }

  Future<void> _exportCsv(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final csvBytes = Uint8List.fromList(
        utf8.encode(buildConsuntivoCsv(data)),
      );
      final fileName = '${_exportFileBaseName()}.csv';
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile.fromData(csvBytes, mimeType: 'text/csv')],
          fileNameOverrides: [fileName],
          subject: 'Consuntivo ore ${data.periodLabel}',
        ),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Export CSV non riuscito su questo dispositivo.'),
        ),
      );
    }
  }
}
