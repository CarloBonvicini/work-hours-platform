import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_hours_mobile/domain/models/schedule_override.dart';

import 'support/app_test_harness.dart';

void main() {
  /// Ieri: orario presente, nessuna ora registrata.
  String yesterdayIsoDate() {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return '${yesterday.year.toString().padLeft(4, '0')}-'
        '${yesterday.month.toString().padLeft(2, '0')}-'
        '${yesterday.day.toString().padLeft(2, '0')}';
  }

  testWidgets('un giorno con orario ma senza ore lo dice e le registra', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final isoDate = yesterdayIsoDate();
    final repository = FakeDashboardRepository(
      initialWorkEntries: const [],
      initialScheduleOverrides: {
        isoDate: ScheduleOverride(
          id: 'override-ieri',
          date: isoDate,
          targetMinutes: 480,
          startTime: '08:15',
          endTime: '17:20',
          breakMinutes: 0,
        ),
      },
    );

    await pumpWorkHoursApp(tester, repository: repository);
    await dismissUpdateDialogIfAny(tester);
    await openHomeSection(tester, 'day');

    // Dal giorno di oggi a ieri.
    await tester.tap(find.byKey(const ValueKey('calendar-prev-month')));
    await tester.pumpAndSettle();
    await openQuickDayEditor(tester);

    final registerButton = find.byKey(
      const ValueKey('calendar-register-unrecorded-hours-button'),
    );
    await tester.ensureVisible(registerButton);
    await tester.pumpAndSettle();

    // 08:15-17:20 sono 9:05 di presenza. Le regole impongono 30 minuti di
    // pausa minima, quindi le ore sono 8:35: la stessa regola che usa il
    // contatore dal vivo e la registrazione all'uscita.
    expect(find.text('Registra 8:35'), findsOneWidget);
    expect(repository.workEntries, isEmpty);

    await tester.tap(registerButton);
    await tester.pumpAndSettle();

    expect(repository.workEntries, hasLength(1));
    expect(repository.workEntries.single.date, isoDate);
    expect(repository.workEntries.single.minutes, (8 * 60) + 35);
    // Registrate: la segnalazione sparisce.
    expect(registerButton, findsNothing);
  });
}
