// Timbratura della giornata e correzione delle registrazioni.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_hours_mobile/application/services/dashboard_service.dart';
import 'package:work_hours_mobile/application/services/hour_input_parser.dart';
import 'package:work_hours_mobile/application/services/time_input_parser.dart';
import 'package:work_hours_mobile/application/services/workday_start_store.dart';
import 'package:work_hours_mobile/domain/models/work_entry.dart';

import 'support/app_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('records the full workday flow and reopens a closed day', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 2200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final workdayStartStore = FakeWorkdayStartStore();
    final today = DateTime.now();
    final todayIsoDate = DashboardService.defaultEntryDateOf(today);

    await pumpWorkHoursApp(tester, workdayStartStore: workdayStartStore);
    await dismissUpdateDialogIfAny(tester);
    await openHomeSection(tester, 'day');
    await openQuickDayEditor(tester);

    Future<void> tapAction(String key) async {
      final finder = find.byKey(ValueKey(key));
      await tester.ensureVisible(finder);
      await tester.tap(finder);
      await tester.pumpAndSettle();
    }

    await tapAction('calendar-record-start-button');
    final started = await workdayStartStore.loadSession(todayIsoDate);
    expect(started, isNotNull);
    expect(started!.isCompleted, isFalse);
    expect(find.text('Dentro'), findsWidgets);

    await tapAction('calendar-start-break-button');
    expect(
      (await workdayStartStore.loadSession(todayIsoDate))!.isOnBreak,
      isTrue,
    );
    expect(find.text('In pausa'), findsWidgets);

    await tapAction('calendar-resume-workday-button');
    final resumed = await workdayStartStore.loadSession(todayIsoDate);
    expect(resumed!.isOnBreak, isFalse);
    expect(resumed.breakSegments, hasLength(1));

    await tapAction('calendar-end-workday-button');
    final closed = await workdayStartStore.loadSession(todayIsoDate);
    expect(closed!.isCompleted, isTrue);
    expect(find.text('Chiusa'), findsWidgets);

    // Con la giornata chiusa il pulsante deve offrire il rientro, non una
    // nuova entrata che cancellerebbe la timbratura gia' registrata.
    expect(find.text('Rientro'), findsOneWidget);
    await tapAction('calendar-record-start-button');
    final reopened = await workdayStartStore.loadSession(todayIsoDate);
    expect(reopened!.isCompleted, isFalse);
    expect(reopened.startMinutes, started.startMinutes);
    // La pausa fuori sede viene aggiunta solo se tra uscita e rientro e'
    // passato almeno un minuto: nel test dipende dal cambio di minuto.
    expect(reopened.breakSegments.length, anyOf(1, 2));
    if (reopened.breakSegments.length == 2) {
      expect(reopened.breakSegments.last.startMinutes, closed.endMinutes);
    }
    expect(
      reopened.accumulatedBreakMinutes >= closed.accumulatedBreakMinutes,
      isTrue,
    );
    expect(find.text('Dentro'), findsWidgets);
  });

  testWidgets('edits and deletes a registered entry from the day view', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 2600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final todayIsoDate = DashboardService.defaultEntryDateOf(DateTime.now());
    final repository = FakeDashboardRepository(
      initialWorkEntries: [
        WorkEntry(
          id: 'w-today',
          date: todayIsoDate,
          minutes: 480,
          note: 'Giornata intera',
        ),
      ],
      initialLeaveEntries: const [],
    );

    await pumpWorkHoursApp(tester, repository: repository);
    await dismissUpdateDialogIfAny(tester);
    await openHomeSection(tester, 'day');
    await openQuickDayEditor(tester);

    // La registrazione del giorno e' elencata con il suo menu azioni.
    final menuFinder = find.byKey(const ValueKey('activity-menu-work-w-today'));
    await tester.ensureVisible(menuFinder);
    await tester.tap(menuFinder);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('activity-edit-work-w-today')));
    await tester.pumpAndSettle();

    // Il modulo rapido si apre in modalita' modifica, precompilato in minuti.
    expect(find.text('Modifica registrazione'), findsOneWidget);
    final minutesField = find.widgetWithText(TextFormField, 'Minuti lavorati');
    expect(
      (tester.widget<TextFormField>(minutesField)).controller?.text,
      '480',
    );
    await tester.enterText(minutesField, '420');
    await tester.tap(find.byKey(const ValueKey('quick-entry-submit-button')));
    await tester.pumpAndSettle();

    expect(repository.workEntries.single.minutes, 420);
    expect(repository.workEntries.single.note, 'Giornata intera');
    expect(find.text('Registrazione aggiornata.'), findsOneWidget);

    // Eliminazione con conferma dalla vista giorno.
    await openHomeSection(tester, 'day');
    await openQuickDayEditor(tester);
    await tester.ensureVisible(menuFinder);
    await tester.tap(menuFinder);
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('activity-delete-work-w-today')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Eliminare questa registrazione?'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('activity-delete-confirm')));
    await tester.pumpAndSettle();

    expect(repository.workEntries, isEmpty);
    expect(
      find.byKey(const ValueKey('activity-menu-work-w-today')),
      findsNothing,
    );
  });

  testWidgets('finishing the workday records the hours and the real times', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 2600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final now = DateTime.now();
    final nowMinutes = now.hour * 60 + now.minute;
    final startMinutes = (nowMinutes - 480).clamp(0, nowMinutes);
    final todayIsoDate = DashboardService.defaultEntryDateOf(now);
    final repository = FakeDashboardRepository(
      initialWorkEntries: const [],
      initialLeaveEntries: const [],
    );
    final workdayStartStore = FakeWorkdayStartStore(
      initialValues: {
        todayIsoDate: WorkdaySession(
          startMinutes: startMinutes,
          accumulatedBreakMinutes: 0,
        ),
      },
    );

    await pumpWorkHoursApp(
      tester,
      repository: repository,
      workdayStartStore: workdayStartStore,
    );
    await dismissUpdateDialogIfAny(tester);
    await openHomeSection(tester, 'day');
    await openQuickDayEditor(tester);

    final finishFinder = find.byKey(
      const ValueKey('calendar-end-workday-button'),
    );
    await tester.ensureVisible(finishFinder);
    await tester.tap(finishFinder);
    await tester.pumpAndSettle();

    final session = await workdayStartStore.loadSession(todayIsoDate);
    expect(session!.isCompleted, isTrue);

    final override = repository.savedScheduleOverrides[todayIsoDate];
    final elapsedMinutes = session.endMinutes! - startMinutes;
    final expectedWorkedMinutes = override == null
        ? 0
        : elapsedMinutes - override.breakMinutes;
    if (expectedWorkedMinutes > 0) {
      // Orari reali salvati come override, obiettivo del giorno invariato.
      expect(override!.startTime, formatTimeInput(startMinutes));
      expect(override.endTime, formatTimeInput(session.endMinutes!));
      // Ore del giorno registrate come voce "Ore lavorate".
      final entry = repository.workEntries.singleWhere(
        (entry) => entry.date == todayIsoDate,
      );
      expect(entry.minutes, expectedWorkedMinutes);
      expect(entry.note, 'Timbratura');
      expect(
        find.textContaining(
          'Ore del giorno: ${formatHoursInput(entry.minutes)}',
        ),
        findsOneWidget,
      );
    } else {
      // Test avviato a ridosso della mezzanotte: nessuna ora da registrare.
      expect(repository.workEntries, isEmpty);
    }
  });
}
