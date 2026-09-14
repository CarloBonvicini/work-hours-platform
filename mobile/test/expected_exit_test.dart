import 'package:flutter_test/flutter_test.dart';
import 'package:work_hours_mobile/domain/models/user_work_rules.dart';
import 'package:work_hours_mobile/presentation/home/logic/expected_exit.dart';
import 'package:work_hours_mobile/presentation/home/logic/schedule_draft.dart';

void main() {
  group('resolveExitAnchorStartMinutes', () {
    final rules = UserWorkRules.unbounded(expectedDailyMinutes: 8 * 60);
    const planned = 8 * 60;

    int anchor(int actual, UserWorkRules workRules) {
      return resolveExitAnchorStartMinutes(
        actualStartMinutes: actual,
        plannedStartMinutes: planned,
        workRules: workRules,
      );
    }

    test('senza orario fisso conta l entrata vera', () {
      expect(anchor(8 * 60 + 15, rules), 8 * 60 + 15);
      expect(anchor(7 * 60 + 45, rules), 7 * 60 + 45);
    });

    test('con orario fisso conta l entrata del piano', () {
      final fixed = rules.copyWith(fixedScheduleEnabled: true);
      expect(anchor(8 * 60 + 15, fixed), planned);
      expect(anchor(7 * 60 + 45, fixed), planned);
    });

    test('la flessibilita sposta l entrata solo dentro la fascia', () {
      final flexible = rules.copyWith(
        fixedScheduleEnabled: true,
        flexibleStartEnabled: true,
        flexibleStartWindowMinutes: 2 * 60,
      );
      expect(anchor(9 * 60, flexible), 9 * 60);
      expect(anchor(10 * 60 + 30, flexible), 10 * 60);
      expect(anchor(7 * 60 + 30, flexible), planned);
    });

    test('scrivendo l entrata a mano vale la stessa regola', () {
      // Orario fisso 08:00: entrare alle 08:15 non sposta l'uscita.
      expect(
        resolveDraftExitMinutes(
          startTimeText: '08:15',
          breakText: '1:00',
          targetMinutes: 8 * 60,
          plannedStartMinutes: planned,
          workRules: rules.copyWith(fixedScheduleEnabled: true),
        ),
        17 * 60,
      );
    });
  });

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
