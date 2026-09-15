import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_hours_mobile/presentation/home/logic/hours_labels.dart';
import 'package:work_hours_mobile/presentation/theme/work_hours_colors.dart';

void main() {
  group('il colore del saldo', () {
    test('avanti e indietro sono due tinte diverse', () {
      expect(
        WorkHoursColors.light.forBalance(60),
        isNot(WorkHoursColors.light.forBalance(-60)),
      );
    });

    test('in pari non punta da nessuna parte', () {
      expect(
        WorkHoursColors.light.forBalance(0),
        WorkHoursColors.light.neutral,
      );
    });

    test('vale in entrambi i temi', () {
      expect(WorkHoursColors.dark.forBalance(60), WorkHoursColors.dark.credit);
      expect(WorkHoursColors.dark.forBalance(-60), WorkHoursColors.dark.debit);
    });
  });

  testWidgets('il tema porta le tinte registrate', (tester) async {
    late WorkHoursColors fromTheme;

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          brightness: Brightness.light,
          extensions: const [WorkHoursColors.light],
        ),
        home: Builder(
          builder: (context) {
            fromTheme = WorkHoursColors.of(context);
            return const SizedBox();
          },
        ),
      ),
    );

    expect(fromTheme.credit, WorkHoursColors.light.credit);
  });

  test('senza estensione registrata si ripiega sul tema giusto', () {
    // Non passa da MaterialApp: qui conta solo la regola di ripiego.
    expect(
      WorkHoursColors.ofTheme(ThemeData.dark()).credit,
      WorkHoursColors.dark.credit,
    );
    expect(
      WorkHoursColors.ofTheme(ThemeData.light()).credit,
      WorkHoursColors.light.credit,
    );
  });

  group('le durate hanno una forma sola', () {
    test('ore e minuti, sempre h:mm', () {
      expect(formatHours(8 * 60), '8:00');
      expect(formatHours(30), '0:30');
      expect(formatHours(84 * 60), '84:00');
    });

    test('anche con il segno', () {
      expect(formatHours(90, signed: true), '+1:30');
      expect(formatHours(-90, signed: true), '-1:30');
      expect(formatHours(0, signed: true), '0:00');
    });

    test('niente piu la forma con la h', () {
      for (final minutes in [30, 60, 90, 8 * 60]) {
        expect(formatHours(minutes).contains('h'), isFalse);
        expect(formatHours(minutes, signed: true).contains('h'), isFalse);
      }
    });
  });
}
