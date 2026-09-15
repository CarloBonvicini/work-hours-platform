import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/app_test_harness.dart';

void main() {
  /// Il tasto indietro di sistema, come lo manda Android.
  Future<void> pressSystemBack(WidgetTester tester) async {
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
  }

  Future<void> openApp(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpWorkHoursApp(tester);
    await dismissUpdateDialogIfAny(tester);
  }

  testWidgets('il tasto indietro torna alla sezione precedente', (
    tester,
  ) async {
    await openApp(tester);

    await openHomeSection(tester, 'day');
    expect(find.text('Oggi'), findsWidgets);

    await openHomeSection(tester, 'workSettings');
    expect(find.text('Orari e permessi'), findsWidgets);

    await pressSystemBack(tester);

    // Si torna a Oggi, non si esce dall'app.
    expect(find.byKey(const ValueKey('today-swipe-day-navigation')),
        findsOneWidget);
  });

  testWidgets('torna indietro un passo alla volta', (tester) async {
    await openApp(tester);

    await openHomeSection(tester, 'day');
    await openHomeSection(tester, 'consuntivo');
    await openHomeSection(tester, 'workSettings');

    await pressSystemBack(tester);
    expect(find.text('Consuntivo'), findsWidgets);

    await pressSystemBack(tester);
    expect(find.byKey(const ValueKey('today-swipe-day-navigation')),
        findsOneWidget);
  });
}
