import 'package:flutter_test/flutter_test.dart';
import 'package:work_hours_mobile/presentation/home/consuntivo_export.dart';
import 'package:work_hours_mobile/presentation/home/consuntivo_section.dart';

ConsuntivoSectionData _sampleData() {
  return const ConsuntivoSectionData(
    anchorMonthLabel: 'Luglio 2026',
    periodLabel: 'Maggio 2026 - Luglio 2026',
    totals: ConsuntivoTotals(
      expectedMinutes: 480 * 3,
      workedMinutes: (480 * 3) + 90,
      leaveMinutes: 60,
      rawBalanceMinutes: 150,
      clampedBalanceMinutes: 120,
      overtimeMaturedMinutes: 150,
      debitMaturedMinutes: 0,
    ),
    months: [
      ConsuntivoMonthSummary(
        monthLabel: 'Maggio 2026',
        expectedMinutes: 480,
        workedMinutes: 480,
        leaveMinutes: 0,
        balanceMinutes: 0,
      ),
      ConsuntivoMonthSummary(
        monthLabel: 'Giugno 2026',
        expectedMinutes: 480,
        workedMinutes: 570,
        leaveMinutes: 60,
        balanceMinutes: 150,
      ),
    ],
    permissions: [],
    days: [
      ConsuntivoDaySummary(
        dateLabel: 'lun 01/06',
        plannedLabel: '8:00',
        registeredLabel: '9:30',
        balanceMinutes: 90,
        scheduleDetail: 'Dettaglio: 08:30-18:30, pausa 0:30',
        causalDetail: 'Note: cliente; trasferta',
      ),
    ],
    hiddenDaysCount: 2,
  );
}

void main() {
  test('il CSV contiene periodo, totali, mesi e giorni', () {
    final csv = buildConsuntivoCsv(_sampleData());
    final lines = csv.trim().split('\r\n');

    expect(lines.first, 'Consuntivo ore;Maggio 2026 - Luglio 2026');
    expect(csv, contains('Ore previste;24:00'));
    expect(csv, contains('Saldo;+2:30'));
    expect(csv, contains('Giugno 2026;8:00;9:30;1:00;+2:30'));
    expect(csv, contains('lun 01/06;8:00;9:30;+1:30'));
    expect(csv, contains('Altri 2 giorni non inclusi'));
  });

  test('le celle con separatore vengono racchiuse tra virgolette', () {
    final csv = buildConsuntivoCsv(_sampleData());
    expect(csv, contains('"Note: cliente; trasferta"'));
  });

  test('il PDF viene generato con intestazione valida', () async {
    final pdfBytes = await buildConsuntivoPdf(_sampleData());

    expect(pdfBytes, isNotEmpty);
    expect(String.fromCharCodes(pdfBytes.take(5)), '%PDF-');
  });

  test('formatConsuntivoSignedHours gestisce zero, credito e debito', () {
    expect(formatConsuntivoSignedHours(0), '0:00');
    expect(formatConsuntivoSignedHours(90), '+1:30');
    expect(formatConsuntivoSignedHours(-45), '-0:45');
  });
}
