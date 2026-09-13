import 'package:flutter_test/flutter_test.dart';
import 'package:work_hours_mobile/domain/models/weekday_target_minutes.dart';
import 'package:work_hours_mobile/presentation/home/logic/initial_setup_answers.dart';

void main() {
  group('InitialSetupAnswers', () {
    test('le ore del giorno sono quelle al netto della pausa', () {
      const answers = InitialSetupAnswers(
        workingDays: {WeekdayKey.monday},
        startMinutes: 9 * 60,
        endMinutes: 18 * 60,
        breakMinutes: 60,
      );

      expect(answers.dailyTargetMinutes, 8 * 60);
      expect(answers.isUsable, isTrue);
      expect(answers.problem, isNull);
    });

    test('segnala quando manca un giorno di lavoro', () {
      const answers = InitialSetupAnswers(
        workingDays: {},
        startMinutes: 9 * 60,
        endMinutes: 18 * 60,
        breakMinutes: 60,
      );

      expect(answers.isUsable, isFalse);
      expect(answers.problem, 'Scegli almeno un giorno di lavoro.');
    });

    test('segnala un uscita prima dell entrata', () {
      const answers = InitialSetupAnswers(
        workingDays: {WeekdayKey.monday},
        startMinutes: 18 * 60,
        endMinutes: 9 * 60,
        breakMinutes: 0,
      );

      expect(answers.isUsable, isFalse);
      expect(answers.problem, 'L uscita deve essere dopo l entrata.');
    });

    test('segnala una pausa che copre tutta la giornata', () {
      const answers = InitialSetupAnswers(
        workingDays: {WeekdayKey.monday},
        startMinutes: 9 * 60,
        endMinutes: 10 * 60,
        breakMinutes: 60,
      );

      expect(answers.dailyTargetMinutes, 0);
      expect(answers.problem, 'La pausa non puo coprire tutta la giornata.');
    });

    test('costruisce l orario solo sui giorni scelti', () {
      const answers = InitialSetupAnswers(
        workingDays: {WeekdayKey.saturday, WeekdayKey.sunday},
        startMinutes: 8 * 60,
        endMinutes: 14 * 60,
        breakMinutes: 30,
      );

      final schedule = answers.buildWeekdaySchedule();

      expect(schedule.saturday.targetMinutes, (5 * 60) + 30);
      expect(schedule.saturday.startTime, '08:00');
      expect(schedule.saturday.endTime, '14:00');
      expect(schedule.saturday.breakMinutes, 30);
      expect(schedule.sunday.targetMinutes, (5 * 60) + 30);
      expect(schedule.monday.targetMinutes, 0);
      expect(schedule.monday.startTime, isNull);
    });

    test('le ore attese del contratto seguono le risposte', () {
      const answers = InitialSetupAnswers(
        workingDays: {WeekdayKey.saturday},
        startMinutes: 8 * 60,
        endMinutes: 14 * 60,
        breakMinutes: 30,
      );

      // Il sabato e l unico giorno lavorato: le ore attese sono le sue.
      expect(answers.buildWorkRules().expectedDailyMinutes, (5 * 60) + 30);
      expect(answers.buildWeekdayTargetMinutes().saturday, (5 * 60) + 30);
      expect(answers.buildWeekdayTargetMinutes().monday, 0);
    });

    test('i valori di partenza sono una settimana lun-ven sensata', () {
      const defaults = InitialSetupAnswers.defaults;

      expect(defaults.workingDays, hasLength(5));
      expect(defaults.workingDays.contains(WeekdayKey.saturday), isFalse);
      expect(defaults.dailyTargetMinutes, 8 * 60);
      expect(defaults.problem, isNull);
    });
  });
}
