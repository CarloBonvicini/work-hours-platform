// Preferenze di layout della vista Oggi: riquadri aperti o ridotti.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/app_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('persists collapsed state for quick day editor', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final themePreferenceStore = FakeThemePreferenceStore();

    Future<void> openDaySection() async {
      await openHomeSection(tester, 'day');
    }

    await pumpWorkHoursApp(tester, themePreferenceStore: themePreferenceStore);

    await tester.pumpAndSettle();
    await dismissUpdateDialogIfAny(tester);
    await openDaySection();

    // Di default la modifica rapida e' chiusa: in cima c'e' la timbratura.
    expect(
      find.byKey(const ValueKey('calendar-override-start-time-button')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('calendar-quick-editor-summary')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('calendar-quick-editor-toggle-button')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('calendar-override-start-time-button')),
      findsOneWidget,
    );
    expect(themePreferenceStore.settings.expandDayQuickEditor, isTrue);

    await pumpWorkHoursApp(
      tester,
      themePreferenceStore: themePreferenceStore,
      initialAppearanceSettings: themePreferenceStore.settings,
    );

    await tester.pumpAndSettle();
    await dismissUpdateDialogIfAny(tester);
    await openDaySection();

    // Chi la apre se la ritrova aperta al rientro.
    expect(
      find.byKey(const ValueKey('calendar-override-start-time-button')),
      findsOneWidget,
    );
  });

  testWidgets('persists collapsed state for the today workday card', (
    tester,
  ) async {
    final themePreferenceStore = FakeThemePreferenceStore();

    Future<void> openDaySection() async {
      await openHomeSection(tester, 'day');
    }

    await pumpWorkHoursApp(tester, themePreferenceStore: themePreferenceStore);

    await tester.pumpAndSettle();
    await dismissUpdateDialogIfAny(tester);
    await openDaySection();

    expect(
      find.byKey(const ValueKey('calendar-record-start-button')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('calendar-workday-card-toggle-button')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('calendar-record-start-button')),
      findsNothing,
    );
    expect(find.text('Giornata di oggi'), findsNothing);
    expect(find.text('Entrata, pausa, uscita.'), findsOneWidget);
    expect(themePreferenceStore.settings.expandDayWorkdayCard, isFalse);

    await pumpWorkHoursApp(
      tester,
      themePreferenceStore: themePreferenceStore,
      initialAppearanceSettings: themePreferenceStore.settings,
    );

    await tester.pumpAndSettle();
    await dismissUpdateDialogIfAny(tester);
    await openDaySection();

    expect(
      find.byKey(const ValueKey('calendar-workday-card-toggle-button')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('calendar-record-start-button')),
      findsNothing,
    );
    expect(find.text('Giornata di oggi'), findsNothing);
    expect(find.text('Entrata, pausa, uscita.'), findsOneWidget);
  });

  testWidgets('persists collapsed state for day agenda', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final themePreferenceStore = FakeThemePreferenceStore();

    Future<void> openDaySection() async {
      await openHomeSection(tester, 'day');
    }

    await pumpWorkHoursApp(tester, themePreferenceStore: themePreferenceStore);

    await tester.pumpAndSettle();
    await dismissUpdateDialogIfAny(tester);
    await openDaySection();

    expect(
      find.byKey(const ValueKey('calendar-day-agenda-toggle-button')),
      findsOneWidget,
    );
    expect(themePreferenceStore.settings.expandDayAgenda, isFalse);
    await tester.ensureVisible(
      find.byKey(const ValueKey('calendar-day-agenda-toggle-button')),
    );

    await tester.tap(
      find.byKey(const ValueKey('calendar-day-agenda-toggle-button')),
    );
    await tester.pumpAndSettle();

    expect(themePreferenceStore.settings.expandDayAgenda, isTrue);

    await tester.ensureVisible(
      find.byKey(const ValueKey('calendar-day-agenda-toggle-button')),
    );
    await tester.tap(
      find.byKey(const ValueKey('calendar-day-agenda-toggle-button')),
    );
    await tester.pumpAndSettle();

    expect(themePreferenceStore.settings.expandDayAgenda, isFalse);

    await pumpWorkHoursApp(
      tester,
      themePreferenceStore: themePreferenceStore,
      initialAppearanceSettings: themePreferenceStore.settings,
    );

    await tester.pumpAndSettle();
    await dismissUpdateDialogIfAny(tester);
    await openDaySection();

    expect(
      find.byKey(const ValueKey('calendar-day-agenda-toggle-button')),
      findsOneWidget,
    );
    expect(find.text('Agenda oraria'), findsOneWidget);
  });

  testWidgets('expands collapsible day sections when tapping the title', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    Future<void> openDaySection() async {
      await openHomeSection(tester, 'day');
    }

    await pumpWorkHoursApp(tester);

    await tester.pumpAndSettle();
    await dismissUpdateDialogIfAny(tester);
    await openDaySection();

    // La modifica rapida arriva gia' chiusa: qui si riduce solo la timbratura.
    await tester.tap(
      find.byKey(const ValueKey('calendar-workday-card-toggle-button')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('calendar-record-start-button')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('calendar-override-start-time-button')),
      findsNothing,
    );

    await tester.tap(find.text('Entrata, pausa, uscita.'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('calendar-record-start-button')),
      findsOneWidget,
    );

    await tester.tap(find.text('Modifica rapida'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('calendar-override-start-time-button')),
      findsOneWidget,
    );

    await tester.tap(find.text('Agenda oraria'));
    await tester.pumpAndSettle();
    // Cosa c'e' dentro l'agenda dipende dal piano del giorno della settimana:
    // qui conta solo che la sezione si sia aperta.
    expect(
      find.byKey(const ValueKey('calendar-day-agenda-body')),
      findsOneWidget,
    );
  });
}
