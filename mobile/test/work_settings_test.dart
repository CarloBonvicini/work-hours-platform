// Impostazioni di orario di lavoro e giorni lavorativi.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/app_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('organizes work settings into clear sections', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await pumpWorkHoursApp(tester);

    await tester.pumpAndSettle();
    await dismissUpdateDialogIfAny(tester);

    await openHomeSection(tester, 'workSettings');

    expect(find.text('Orario di lavoro'), findsOneWidget);
    expect(find.text('Quanto devi lavorare'), findsNothing);
    expect(find.text('Limiti'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('work-settings-schedule-toggle-button')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('work-settings-limits-toggle-button')),
      findsOneWidget,
    );
    expect(
      find.text(
        'Scegli il massimo credito o debito che l app puo conteggiare nel giorno e nel mese. Se non vuoi limiti, lascia Nessun limite.',
      ),
      findsOneWidget,
    );
    expect(find.text('Stesso orario tutti i giorni'), findsOneWidget);
    expect(find.text('Disattiva per personalizzare i giorni.'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('work-settings-lunch-break-monday')),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is RichText &&
            widget.text.toPlainText().contains('Pausa minima'),
      ),
      findsWidgets,
    );
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is RichText &&
            widget.text.toPlainText().contains('Nessun limite'),
      ),
      findsWidgets,
    );
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is RichText &&
            widget.text.toPlainText().contains('Max credito giorno'),
      ),
      findsWidgets,
    );
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is RichText &&
            widget.text.toPlainText().contains('Max debito mese'),
      ),
      findsWidgets,
    );
    expect(find.text('Ripristina valori'), findsOneWidget);
    expect(find.text('Salva'), findsOneWidget);
    expect(find.text('Ore giornaliere attese'), findsNothing);
    expect(find.text('Carica orari'), findsNothing);
    expect(find.text('Salva orari'), findsNothing);
  });

  testWidgets('saves weekend work while keeping the uniform schedule', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 2600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final repository = FakeDashboardRepository();
    await pumpWorkHoursApp(tester, repository: repository);
    await dismissUpdateDialogIfAny(tester);
    await openHomeSection(tester, 'workSettings');

    // Passa all'orario unico: il selettore dei giorni deve restare disponibile.
    final uniformSwitch = find.ancestor(
      of: find.text('Stesso orario tutti i giorni'),
      matching: find.byType(SwitchListTile),
    );
    await tester.ensureVisible(uniformSwitch);
    await tester.tap(uniformSwitch);
    await tester.pumpAndSettle();

    final saturdayToggle = find.byKey(
      const ValueKey('work-settings-working-day-toggle-saturday'),
    );
    await tester.ensureVisible(saturdayToggle);
    await tester.tap(saturdayToggle);
    await tester.pumpAndSettle();

    final saveButton = find.widgetWithText(FilledButton, 'Salva');
    await tester.ensureVisible(saveButton);
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    final savedSchedule = repository.savedWeekdaySchedule;
    expect(savedSchedule, isNotNull);
    expect(savedSchedule!.saturday.targetMinutes, greaterThan(0));
    expect(savedSchedule.monday.targetMinutes, greaterThan(0));
    // La domenica non e' stata scelta: resta libera.
    expect(savedSchedule.sunday.targetMinutes, 0);
  });

  testWidgets('toggles weekday lunch break in work settings', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await pumpWorkHoursApp(tester);

    await tester.pumpAndSettle();
    await dismissUpdateDialogIfAny(tester);

    await openHomeSection(tester, 'workSettings');

    final mondayLunchBreakFinder = find.byKey(
      const ValueKey('work-settings-lunch-break-monday'),
    );
    expect(mondayLunchBreakFinder, findsOneWidget);
    expect(tester.widget<Checkbox>(mondayLunchBreakFinder).value, isTrue);

    await tester.tap(mondayLunchBreakFinder);
    await tester.pumpAndSettle();

    expect(tester.widget<Checkbox>(mondayLunchBreakFinder).value, isFalse);
  });

  testWidgets('persists collapsed state for work settings sections', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 2200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final themePreferenceStore = FakeThemePreferenceStore();

    Future<void> openWorkSettings() async {
      final workSettingsOptionFinder = find.byKey(
        const ValueKey('navigation-option-workSettings'),
      );

      for (var attempt = 0; attempt < 3; attempt += 1) {
        if (workSettingsOptionFinder.evaluate().isNotEmpty) {
          await tester.tap(workSettingsOptionFinder.first);
          await tester.pumpAndSettle();
          return;
        }

        final menuButtonFinder = find.byKey(
          const ValueKey('navigation-menu-button'),
        );
        if (menuButtonFinder.evaluate().isEmpty) {
          await tester.pump(const Duration(milliseconds: 120));
          continue;
        }

        await tester.tap(menuButtonFinder.first);
        await tester.pumpAndSettle();
      }

      final workSettingsTitle = find.text('Orari e permessi');
      if (workSettingsTitle.evaluate().isNotEmpty) {
        return;
      }

      fail('Impossibile aprire la sezione Orari e permessi nel test widget.');
    }

    await pumpWorkHoursApp(tester, themePreferenceStore: themePreferenceStore);

    await tester.pumpAndSettle();
    await dismissUpdateDialogIfAny(tester);
    await openWorkSettings();

    expect(themePreferenceStore.settings.expandWorkSettingsLimits, isTrue);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('work-settings-limits-toggle-button')),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(
      find.byKey(const ValueKey('work-settings-limits-toggle-button')),
    );
    await tester.pumpAndSettle();

    expect(themePreferenceStore.settings.expandWorkSettingsLimits, isFalse);
    expect(
      find.text(
        'Scegli il massimo credito o debito che l app puo conteggiare nel giorno e nel mese. Se non vuoi limiti, lascia Nessun limite.',
      ),
      findsNothing,
    );
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is RichText &&
            widget.text.toPlainText().contains('Max credito giorno'),
      ),
      findsNothing,
    );

    await pumpWorkHoursApp(
      tester,
      themePreferenceStore: themePreferenceStore,
      initialAppearanceSettings: themePreferenceStore.settings,
    );

    await tester.pumpAndSettle();
    await dismissUpdateDialogIfAny(tester);
    await openWorkSettings();

    expect(themePreferenceStore.settings.expandWorkSettingsLimits, isFalse);
    expect(
      find.byKey(const ValueKey('work-settings-limits-toggle-button')),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is RichText &&
            widget.text.toPlainText().contains('Max credito giorno'),
      ),
      findsNothing,
    );
  });
}
