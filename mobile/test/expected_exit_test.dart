import 'package:flutter_test/flutter_test.dart';
import 'package:work_hours_mobile/presentation/home/logic/expected_exit.dart';

void main() {
  group('resolveExpectedExitMinutes', () {
    test('entrata piu ore da fare piu pausa', () {
      // 08:15 + 8:00 + 60 min = 17:15, il caso della schermata Oggi.
      expect(
        resolveExpectedExitMinutes(
          startMinutes: (8 * 60) + 15,
          targetMinutes: 8 * 60,
          breakMinutes: 60,
        ),
        (17 * 60) + 15,
      );
    });

    test('senza pausa esce prima', () {
      expect(
        resolveExpectedExitMinutes(
          startMinutes: 9 * 60,
          targetMinutes: 8 * 60,
          breakMinutes: 0,
        ),
        17 * 60,
      );
    });
  });

  group('resolveExpectedExitBreakMinutes', () {
    test('la pausa piu lunga gia fatta sposta l uscita', () {
      expect(
        resolveExpectedExitBreakMinutes(
          plannedBreakMinutes: 60,
          actualBreakMinutes: 90,
        ),
        90,
      );
    });

    test('una pausa piu corta di quella prevista non anticipa l uscita', () {
      expect(
        resolveExpectedExitBreakMinutes(
          plannedBreakMinutes: 60,
          actualBreakMinutes: 20,
        ),
        60,
      );
    });

    test('il minimo imposto dalle regole vince su una pausa piu corta', () {
      expect(
        resolveExpectedExitBreakMinutes(
          plannedBreakMinutes: 0,
          actualBreakMinutes: 10,
          minimumBreakMinutes: 30,
        ),
        30,
      );
    });
  });

  group('uscita oltre la mezzanotte', () {
    test('il campo orario resta dentro la giornata', () {
      expect(clampExitToDayEnd((25 * 60) + 30), (23 * 60) + 59);
    });

    test('l etichetta segnala il giorno dopo', () {
      expect(formatExpectedExitLabel((25 * 60) + 30), '01:30 +1g');
      expect(
        formatExpectedExitLabel(
          (25 * 60) + 30,
          nextDaySuffix: ' del giorno dopo',
        ),
        '01:30 del giorno dopo',
      );
    });

    test('dentro la giornata non aggiunge niente', () {
      expect(formatExpectedExitLabel((17 * 60) + 15), '17:15');
    });
  });
}
