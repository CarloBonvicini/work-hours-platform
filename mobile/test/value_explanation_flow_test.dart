import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/app_test_harness.dart';

void main() {
  testWidgets('tenere premuto un numero lo spiega e porta alle impostazioni', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await pumpWorkHoursApp(tester);
    await dismissUpdateDialogIfAny(tester);
    await openHomeSection(tester, 'day');
    await openQuickDayEditor(tester);

    final workedValue = find.byKey(
      const ValueKey('calendar-live-worked-value'),
    );
    await tester.ensureVisible(workedValue);
    await tester.pumpAndSettle();

    await tester.longPress(workedValue);
    await tester.pumpAndSettle();

    // Dice cos'e' e da dove esce.
    expect(find.byKey(const ValueKey('value-explanation-title')), findsOneWidget);
    expect(find.text('Da dove esce'), findsOneWidget);

    // E porta dritto dove si cambia.
    await tester.tap(
      find.byKey(const ValueKey('value-explanation-settings-button')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Regole del contratto'), findsWidgets);
  });

  testWidgets('dalle impostazioni il tasto indietro riporta al giorno', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await pumpWorkHoursApp(tester);
    await dismissUpdateDialogIfAny(tester);
    await openHomeSection(tester, 'day');
    await openQuickDayEditor(tester);

    final workedValue = find.byKey(
      const ValueKey('calendar-live-worked-value'),
    );
    await tester.ensureVisible(workedValue);
    await tester.pumpAndSettle();
    await tester.longPress(workedValue);
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('value-explanation-settings-button')),
    );
    await tester.pumpAndSettle();

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('today-swipe-day-navigation')),
      findsOneWidget,
    );
  });
}
