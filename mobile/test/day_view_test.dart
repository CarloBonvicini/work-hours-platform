// Vista Oggi: contenuti della giornata, orario previsto e layout settimana.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_hours_mobile/domain/models/schedule_override.dart';

import 'support/app_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('shows simplified dashboard flow', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 2200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final today = DateTime.now();
    final todayIsoDate =
        '${today.year.toString().padLeft(4, '0')}-'
        '${today.month.toString().padLeft(2, '0')}-'
        '${today.day.toString().padLeft(2, '0')}';
    final repository = FakeDashboardRepository(
      initialScheduleOverrides: {
        todayIsoDate: ScheduleOverride(
          id: 'today-working-day',
          date: todayIsoDate,
          targetMinutes: 480,
          note: 'Giorno lavorativo per test widget',
        ),
      },
    );

    await pumpWorkHoursApp(tester, repository: repository);

    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('navigation-menu-button')),
      findsOneWidget,
    );
    expect(find.text('Navigazione'), findsNothing);
    expect(find.text('Settimana'), findsWidgets);
    expect(find.text('Impostazioni'), findsNothing);
    expect(find.text('Panoramica del mese'), findsNothing);
    expect(find.byKey(const ValueKey('home-section-overview')), findsNothing);
    expect(find.byKey(const ValueKey('home-section-quickEntry')), findsNothing);
    expect(
      find.byKey(const ValueKey('home-section-recentActivity')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('home-section-profile')), findsNothing);
    expect(find.byKey(const ValueKey('home-section-ticket')), findsNothing);
    expect(find.text('Aggiornamento disponibile'), findsOneWidget);
    expect(find.text('Ricordamelo piu tardi'), findsOneWidget);
    expect(find.text('Aggiorna'), findsNothing);

    await tester.tap(find.text('Ricordamelo piu tardi'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('navigation-menu-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('navigation-option-day')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('navigation-option-consuntivo')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('navigation-option-calendar')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('navigation-option-workSettings')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('navigation-option-profile')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('navigation-option-ticket')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('navigation-option-day')));
    await tester.pumpAndSettle();

    expect(find.text('Oggi'), findsWidgets);
    // La modifica rapida arriva chiusa: in cima c'e' la timbratura, e il
    // riepilogo del giorno si legge senza aprirla.
    expect(
      find.byKey(const ValueKey('calendar-quick-editor-summary')),
      findsOneWidget,
    );
    await openQuickDayEditor(tester);
    expect(
      find.byKey(const ValueKey('calendar-record-start-button')),
      findsOneWidget,
    );
    final hasStandardHoursLabel = find
        .text('Ore di lavoro standard')
        .evaluate()
        .isNotEmpty;
    final hasWorkHoursLabel = find.text('Ore di lavoro').evaluate().isNotEmpty;
    expect(hasStandardHoursLabel || hasWorkHoursLabel, isTrue);
    // Le ore si registrano da sole con Entrata/Uscita: niente riquadro
    // separato, solo le azioni di correzione dentro la modifica rapida.
    expect(find.text('Registrazioni di oggi'), findsNothing);
    expect(find.text('Nessuna registrazione.'), findsNothing);
    expect(
      find.byKey(const ValueKey('quick-day-add-leave-chip')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('quick-day-add-work-chip')),
      findsOneWidget,
    );
    // L'entrata parte gia' dai valori previsti; se il giorno non ne ha,
    // resta l'invito a iniziare.
    final hasStartGuidance =
        find.text('Previsto: conferma o cambia').evaluate().isNotEmpty ||
        find.text('Inizia da qui').evaluate().isNotEmpty;
    expect(hasStartGuidance, isTrue);
    expect(
      tester
          .widget<Text>(
            find.byKey(const ValueKey('calendar-live-day-balance-value')),
          )
          .data,
      'Da iniziare',
    );
    expect(
      tester
          .widget<Text>(
            find.byKey(const ValueKey('calendar-live-overtime-value')),
          )
          .data,
      'Da calcolare',
    );
    await tester.tap(
      find.byKey(const ValueKey('calendar-record-start-button')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('calendar-start-break-button')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('calendar-end-workday-button')),
      findsOneWidget,
    );

    expect(
      find.byKey(const ValueKey('calendar-override-start-time-button')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('calendar-override-target-value')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('calendar-override-end-time-button')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('calendar-override-break-value')),
      findsOneWidget,
    );
    expect(find.text('Lavorate'), findsOneWidget);
    expect(find.text('Saldo mese'), findsOneWidget);
    expect(find.text('Straordinario'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('calendar-live-period-balance-label')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('calendar-live-worked-value')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('calendar-live-expected-value')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('calendar-live-day-balance-value')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('calendar-live-month-balance-value')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('calendar-live-overtime-value')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('calendar-day-agenda-toggle-button')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('calendar-record-start-button')),
      findsNothing,
    );
    expect(find.text('Ore previste per questo giorno'), findsNothing);

    await openHomeSection(tester, 'calendar');

    expect(find.text('Calendario'), findsWidgets);
    expect(find.text('Settimana'), findsWidgets);
    expect(find.text('Mese'), findsWidgets);
    expect(find.text('Anno'), findsWidgets);
    expect(
      find.byKey(const ValueKey('calendar-record-start-button')),
      findsNothing,
    );
  });

  testWidgets(
    'does not treat standard hours as worked when only the target is set',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      Future<void> openDaySection() async {
        await openHomeSection(tester, 'day');
        await openQuickDayEditor(tester);
      }

      final today = DateTime.now();
      final todayIsoDate =
          '${today.year.toString().padLeft(4, '0')}-'
          '${today.month.toString().padLeft(2, '0')}-'
          '${today.day.toString().padLeft(2, '0')}';

      await pumpWorkHoursApp(
        tester,
        repository: FakeDashboardRepository(
          initialScheduleOverrides: {
            todayIsoDate: ScheduleOverride(
              id: 'override-target-only',
              date: todayIsoDate,
              targetMinutes: 475,
            ),
          },
        ),
      );

      await tester.pumpAndSettle();
      if (find.text('Ricordamelo piu tardi').evaluate().isNotEmpty) {
        await tester.tap(find.text('Ricordamelo piu tardi'));
        await tester.pumpAndSettle();
      }
      await openDaySection();

      expect(
        tester
            .widget<Text>(
              find.byKey(const ValueKey('calendar-live-worked-value')),
            )
            .data,
        '0:00',
      );
      expect(
        tester
            .widget<Text>(
              find.byKey(const ValueKey('calendar-live-day-balance-value')),
            )
            .data,
        'Da iniziare',
      );
      expect(
        tester
            .widget<Text>(
              find.byKey(const ValueKey('calendar-live-overtime-value')),
            )
            .data,
        'Da calcolare',
      );

      // Entrata e uscita previste sono gia' pronte nei campi, senza per questo
      // valere come ore registrate.
      expect(find.text('08:30'), findsWidgets);
      expect(find.text('16:25'), findsWidgets);
      expect(find.text('Uscita prevista'), findsOneWidget);
      expect(find.text('Previsto: conferma o cambia'), findsNWidgets(2));
    },
  );

  testWidgets('restores the standard schedule from the day view', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final today = DateTime.now();
    final todayIsoDate =
        '${today.year.toString().padLeft(4, '0')}-'
        '${today.month.toString().padLeft(2, '0')}-'
        '${today.day.toString().padLeft(2, '0')}';
    final repository = FakeDashboardRepository(
      initialScheduleOverrides: {
        todayIsoDate: ScheduleOverride(
          id: 'override-da-ripristinare',
          date: todayIsoDate,
          targetMinutes: 300,
          startTime: '10:00',
          endTime: '15:00',
        ),
      },
    );

    await pumpWorkHoursApp(tester, repository: repository);
    await dismissUpdateDialogIfAny(tester);
    await openHomeSection(tester, 'day');
    await openQuickDayEditor(tester);

    // L'eccezione del giorno non e' una giornata libera: deve restare
    // possibile tornare all'orario standard.
    final restoreFinder = find.byKey(
      const ValueKey('quick-day-restore-standard-chip'),
    );
    await tester.ensureVisible(restoreFinder);
    await tester.tap(restoreFinder);
    await tester.pumpAndSettle();

    expect(
      repository.savedScheduleOverrides.containsKey(todayIsoDate),
      isFalse,
    );
    expect(restoreFinder, findsNothing);
  });

  testWidgets('uses a compact week layout on narrow screens', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    String isoDateOf(DateTime date) {
      final year = date.year.toString().padLeft(4, '0');
      final month = date.month.toString().padLeft(2, '0');
      final day = date.day.toString().padLeft(2, '0');
      return '$year-$month-$day';
    }

    final today = DateTime.now();
    final firstDayOfWeek = DateTime(
      today.year,
      today.month,
      today.day - (today.weekday - 1),
    );
    final lastDayOfWeek = firstDayOfWeek.add(const Duration(days: 6));

    await pumpWorkHoursApp(tester);

    await tester.pumpAndSettle();
    await tester.tap(find.text('Ricordamelo piu tardi'));
    await tester.pumpAndSettle();
    await openHomeSection(tester, 'calendar');
    await tester.tap(find.text('Settimana').last);
    await tester.pumpAndSettle();

    expect(find.text('Tocca un giorno per vederlo in grande.'), findsNothing);
    expect(find.text('Giorno selezionato'), findsNothing);
    expect(
      find.byKey(ValueKey('calendar-week-row-${isoDateOf(firstDayOfWeek)}')),
      findsOneWidget,
    );
    expect(
      find.byKey(ValueKey('calendar-week-row-${isoDateOf(lastDayOfWeek)}')),
      findsOneWidget,
    );
    expect(find.text('Pausa 0:30'), findsNothing);
    expect(find.text('08:30 - 15:00'), findsNothing);
  });
}
