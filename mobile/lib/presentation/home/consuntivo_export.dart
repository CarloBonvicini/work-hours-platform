import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:work_hours_mobile/presentation/home/consuntivo_section.dart';

String formatConsuntivoHours(int minutes) {
  final hours = minutes ~/ 60;
  final remainingMinutes = minutes % 60;
  return '$hours:${remainingMinutes.toString().padLeft(2, '0')}';
}

String formatConsuntivoSignedHours(int minutes) {
  if (minutes == 0) {
    return '0:00';
  }
  final sign = minutes > 0 ? '+' : '-';
  return '$sign${formatConsuntivoHours(minutes.abs())}';
}

String _csvCell(String value) {
  if (value.contains(';') || value.contains('"') || value.contains('\n')) {
    return '"${value.replaceAll('"', '""')}"';
  }
  return value;
}

String _csvRow(List<String> cells) {
  return cells.map(_csvCell).join(';');
}

/// Costruisce il CSV del consuntivo (separatore ';', compatibile Excel).
String buildConsuntivoCsv(ConsuntivoSectionData data) {
  final lines = <String>[
    _csvRow(['Consuntivo ore', data.periodLabel]),
    '',
    _csvRow(['Totali', '']),
    _csvRow([
      'Ore previste',
      formatConsuntivoHours(data.totals.expectedMinutes),
    ]),
    _csvRow([
      'Ore registrate',
      formatConsuntivoHours(data.totals.workedMinutes),
    ]),
    _csvRow([
      'Causali (ferie/permessi)',
      formatConsuntivoHours(data.totals.leaveMinutes),
    ]),
    _csvRow([
      'Saldo',
      formatConsuntivoSignedHours(data.totals.rawBalanceMinutes),
    ]),
    _csvRow([
      'Straordinario maturato',
      formatConsuntivoHours(data.totals.overtimeMaturedMinutes),
    ]),
    _csvRow([
      'Debito maturato',
      formatConsuntivoHours(data.totals.debitMaturedMinutes),
    ]),
    '',
    _csvRow(['Mese', 'Previste', 'Registrate', 'Causali', 'Saldo']),
    for (final month in data.months)
      _csvRow([
        month.monthLabel,
        formatConsuntivoHours(month.expectedMinutes),
        formatConsuntivoHours(month.workedMinutes),
        formatConsuntivoHours(month.leaveMinutes),
        formatConsuntivoSignedHours(month.balanceMinutes),
      ]),
    '',
    _csvRow([
      'Giorno',
      'Programmato',
      'Registrato',
      'Saldo',
      'Dettaglio',
      'Causali e note',
    ]),
    for (final day in data.days)
      _csvRow([
        day.dateLabel,
        day.plannedLabel,
        day.registeredLabel,
        formatConsuntivoSignedHours(day.balanceMinutes),
        day.scheduleDetail ?? '',
        day.causalDetail ?? '',
      ]),
    if (data.hiddenDaysCount > 0)
      _csvRow([
        'Altri ${data.hiddenDaysCount} giorni non inclusi',
        '',
        '',
        '',
        '',
        '',
      ]),
  ];

  return '${lines.join('\r\n')}\r\n';
}

/// Costruisce il PDF del consuntivo pronto per stampa o condivisione.
Future<Uint8List> buildConsuntivoPdf(ConsuntivoSectionData data) async {
  final document = pw.Document();

  final headerStyle = pw.TextStyle(
    fontSize: 10,
    fontWeight: pw.FontWeight.bold,
  );
  const cellStyle = pw.TextStyle(fontSize: 9);

  document.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      build: (context) => [
        pw.Text(
          'Consuntivo ore',
          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 4),
        pw.Text('Periodo: ${data.periodLabel}', style: cellStyle),
        pw.SizedBox(height: 14),
        pw.TableHelper.fromTextArray(
          headers: const [
            'Previste',
            'Registrate',
            'Causali',
            'Saldo',
            'Straordinario',
            'Debito',
          ],
          data: [
            [
              formatConsuntivoHours(data.totals.expectedMinutes),
              formatConsuntivoHours(data.totals.workedMinutes),
              formatConsuntivoHours(data.totals.leaveMinutes),
              formatConsuntivoSignedHours(data.totals.rawBalanceMinutes),
              formatConsuntivoHours(data.totals.overtimeMaturedMinutes),
              formatConsuntivoHours(data.totals.debitMaturedMinutes),
            ],
          ],
          headerStyle: headerStyle,
          cellStyle: cellStyle,
        ),
        if (data.months.length > 1) ...[
          pw.SizedBox(height: 14),
          pw.Text('Riepilogo mensile', style: headerStyle),
          pw.SizedBox(height: 6),
          pw.TableHelper.fromTextArray(
            headers: const [
              'Mese',
              'Previste',
              'Registrate',
              'Causali',
              'Saldo',
            ],
            data: [
              for (final month in data.months)
                [
                  month.monthLabel,
                  formatConsuntivoHours(month.expectedMinutes),
                  formatConsuntivoHours(month.workedMinutes),
                  formatConsuntivoHours(month.leaveMinutes),
                  formatConsuntivoSignedHours(month.balanceMinutes),
                ],
            ],
            headerStyle: headerStyle,
            cellStyle: cellStyle,
          ),
        ],
        pw.SizedBox(height: 14),
        pw.Text('Dettaglio giorni', style: headerStyle),
        pw.SizedBox(height: 6),
        if (data.days.isEmpty)
          pw.Text('Nessuna attivita nel periodo selezionato.', style: cellStyle)
        else
          pw.TableHelper.fromTextArray(
            headers: const [
              'Giorno',
              'Programmato',
              'Registrato',
              'Saldo',
              'Dettaglio',
            ],
            data: [
              for (final day in data.days)
                [
                  day.dateLabel,
                  day.plannedLabel,
                  day.registeredLabel,
                  formatConsuntivoSignedHours(day.balanceMinutes),
                  [
                    if (day.scheduleDetail != null) day.scheduleDetail!,
                    if (day.causalDetail != null) day.causalDetail!,
                  ].join('\n'),
                ],
            ],
            headerStyle: headerStyle,
            cellStyle: cellStyle,
            columnWidths: const {
              0: pw.FlexColumnWidth(1.6),
              1: pw.FlexColumnWidth(1),
              2: pw.FlexColumnWidth(1),
              3: pw.FlexColumnWidth(1),
              4: pw.FlexColumnWidth(3),
            },
          ),
        if (data.hiddenDaysCount > 0) ...[
          pw.SizedBox(height: 8),
          pw.Text(
            'Altri ${data.hiddenDaysCount} giorni non inclusi in questo report.',
            style: cellStyle,
          ),
        ],
      ],
    ),
  );

  return document.save();
}
