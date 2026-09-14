import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_hours_mobile/presentation/home/logic/calendar_dates.dart';

import 'support/app_test_harness.dart';

void main() {
  Future<void> openDay(WidgetTester tester) async {
    await pumpWorkHoursApp(tester);
    await dismissUpdateDialogIfAny(tester);
    await openHomeSection(tester, 'day');
  }

  Finder swipeArea() =>
      find.byKey(const ValueKey('today-swipe-day-navigation'));

  /// Trascina e lascia, con abbastanza velocita' da valere come scorrimento.
  Future<void> swipe(WidgetTester tester, Offset offset) async {
    await tester.fling(swipeArea(), offset, 800);
    await tester.pumpAndSettle();
  }

  String labelFor(DateTime date) => formatLongDate(date);

  testWidgets('scorrere verso sinistra porta al giorno dopo', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await openDay(tester);
    final today = DateTime.now();
    expect(find.text(labelFor(today)), findsOneWidget);

    // Destra verso sinistra: come sfogliare in avanti.
    await swipe(tester, const Offset(-300, 0));

    expect(
      find.text(labelFor(today.add(const Duration(days: 1)))),
      findsOneWidget,
    );
  });

  testWidgets('scorrere verso destra porta al giorno prima', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await openDay(tester);
    final today = DateTime.now();

    await swipe(tester, const Offset(300, 0));

    expect(
      find.text(labelFor(today.subtract(const Duration(days: 1)))),
      findsOneWidget,
    );
  });
}
