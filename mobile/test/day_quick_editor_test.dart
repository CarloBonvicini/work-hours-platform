// Modifica rapida del giorno: annulla/ripristina e anteprime orarie.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/app_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('supports undo and redo in quick day editing', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await pumpWorkHoursApp(tester);

    await tester.pumpAndSettle();
    await dismissUpdateDialogIfAny(tester);

    await openHomeSection(tester, 'day');

    final exitPosition = tester.getTopLeft(
      find.byKey(const ValueKey('calendar-override-end-time-button')),
    );
    final targetPosition = tester.getTopLeft(
      find.byKey(const ValueKey('calendar-override-target-value')),
    );
    expect(exitPosition.dy, targetPosition.dy);
    expect(exitPosition.dx, lessThan(targetPosition.dx));

    String readTargetValue() {
      final values = tester
          .widgetList<Text>(
            find.descendant(
              of: find.byKey(const ValueKey('calendar-override-target-value')),
              matching: find.byType(Text),
            ),
          )
          .map((widget) => widget.data?.trim())
          .whereType<String>()
          .where((value) => RegExp(r'^\d{1,2}:\d{2}$').hasMatch(value))
          .toList(growable: false);
      expect(values, isNotEmpty);
      return values.first;
    }

    final initialTargetValue = readTargetValue();

    await tester.tap(
      find.byKey(const ValueKey('calendar-override-day-off-button')),
    );
    await tester.pumpAndSettle();

    expect(readTargetValue(), '0:00');
    expect(
      tester
          .widget<Text>(
            find.byKey(const ValueKey('calendar-live-overtime-value')),
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
      '0:00',
    );

    await tester.tap(
      find.byKey(const ValueKey('calendar-override-undo-button')),
    );
    await tester.pumpAndSettle();

    expect(readTargetValue(), initialTargetValue);

    await tester.tap(
      find.byKey(const ValueKey('calendar-override-redo-button')),
    );
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('calendar-override-target-value')),
        matching: find.text('0:00'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('shows worked hours in the quick day time picker', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await pumpWorkHoursApp(tester);

    await tester.pumpAndSettle();
    await dismissUpdateDialogIfAny(tester);

    await openHomeSection(tester, 'day');

    await tester.tap(
      find.byKey(const ValueKey('calendar-override-end-time-button')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Uscita'), findsWidgets);
    expect(
      find.byKey(const ValueKey('schedule-time-wheel-helper-text')),
      findsOneWidget,
    );
    final helperText = tester
        .widget<Text>(
          find.byKey(const ValueKey('schedule-time-wheel-helper-text')),
        )
        .data;
    expect(helperText, startsWith('Ore di lavoro: '));
  });
}
