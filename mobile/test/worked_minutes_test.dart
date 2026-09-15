import 'package:flutter_test/flutter_test.dart';
import 'package:work_hours_mobile/presentation/home/logic/worked_minutes.dart';

void main() {
  group('la pausa che si scala', () {
    test('e quella registrata nel giorno', () {
      expect(
        resolveCountedBreakMinutes(recordedBreakMinutes: 45),
        45,
      );
    });

    test('non scende sotto il minimo imposto dalle regole', () {
      expect(
        resolveCountedBreakMinutes(
          recordedBreakMinutes: 10,
          minimumBreakMinutes: 30,
        ),
        30,
      );
    });

    test('una pausa piu lunga del minimo vale per intero', () {
      expect(
        resolveCountedBreakMinutes(
          recordedBreakMinutes: 90,
          minimumBreakMinutes: 30,
        ),
        90,
      );
    });

    test('senza minimo e senza pausa non si scala niente', () {
      expect(resolveCountedBreakMinutes(recordedBreakMinutes: 0), 0);
    });
  });

  group('ore lavorate', () {
    test('sono la presenza meno la pausa', () {
      // 08:15-17:20 sono 9:05 di presenza, 30 minuti di pausa.
      expect(
        resolveWorkedMinutes(
          presenceMinutes: (9 * 60) + 5,
          recordedBreakMinutes: 30,
        ),
        (8 * 60) + 35,
      );
    });

    test('saltare la pausa non toglie ore oltre il minimo', () {
      expect(
        resolveWorkedMinutes(
          presenceMinutes: (9 * 60) + 5,
          recordedBreakMinutes: 0,
          minimumBreakMinutes: 30,
        ),
        (8 * 60) + 35,
      );
    });

    test('una pausa piu lunga della presenza non produce ore negative', () {
      expect(
        resolveWorkedMinutes(
          presenceMinutes: 20,
          recordedBreakMinutes: 60,
        ),
        0,
      );
    });
  });
}
