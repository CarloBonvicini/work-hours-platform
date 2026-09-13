import 'package:flutter_test/flutter_test.dart';
import 'package:work_hours_mobile/domain/models/weekday_schedule.dart';
import 'package:work_hours_mobile/domain/models/day_schedule.dart';
import 'package:work_hours_mobile/domain/models/weekday_target_minutes.dart';
import 'package:work_hours_mobile/presentation/home/logic/schedule_draft.dart';

void main() {
  group('WeekdaySchedule.uniform', () {
    test('senza indicazioni resta sui giorni lun-ven', () {
      final schedule = WeekdaySchedule.uniform(
        8 * 60,
        startTime: '09:00',
        endTime: '17:00',
      );

      expect(schedule.monday.targetMinutes, 8 * 60);
      expect(schedule.friday.startTime, '09:00');
      expect(schedule.saturday.targetMinutes, 0);
      expect(schedule.sunday.targetMinutes, 0);
      expect(schedule.sunday.startTime, isNull);
    });

    test('applica lo stesso orario ai giorni lavorativi scelti', () {
      final schedule = WeekdaySchedule.uniform(
        6 * 60,
        startTime: '10:00',
        endTime: '16:30',
        breakMinutes: 30,
        workingDays: const {
          WeekdayKey.saturday,
          WeekdayKey.sunday,
          WeekdayKey.monday,
        },
      );

      expect(schedule.sunday.targetMinutes, 6 * 60);
      expect(schedule.sunday.startTime, '10:00');
      expect(schedule.sunday.endTime, '16:30');
      expect(schedule.sunday.breakMinutes, 30);
      expect(schedule.saturday.targetMinutes, 6 * 60);
      expect(schedule.monday.targetMinutes, 6 * 60);
      // I giorni non scelti restano liberi, senza orari residui.
      expect(schedule.tuesday.targetMinutes, 0);
      expect(schedule.tuesday.startTime, isNull);
      expect(schedule.friday.targetMinutes, 0);
    });

    test('nessun giorno lavorativo produce una settimana vuota', () {
      final schedule = WeekdaySchedule.uniform(8 * 60, workingDays: const {});

      for (final weekday in WeekdayKey.values) {
        expect(schedule.forWeekday(weekday).targetMinutes, 0);
      }
    });
  });

  group('averageWorkingDayTargetMinutes', () {
    test('media solo i giorni con ore previste', () {
      // Quattro giorni da 8 ore e uno libero: la giornata tipo resta 8 ore.
      final schedule = WeekdaySchedule.uniform(
        8 * 60,
        workingDays: const {
          WeekdayKey.monday,
          WeekdayKey.tuesday,
          WeekdayKey.wednesday,
          WeekdayKey.thursday,
        },
      );

      expect(averageWorkingDayTargetMinutes(schedule), 8 * 60);
    });

    test('vale anche quando il lunedi e libero', () {
      final schedule = WeekdaySchedule.uniform(
        6 * 60,
        workingDays: const {WeekdayKey.saturday, WeekdayKey.sunday},
      );

      expect(averageWorkingDayTargetMinutes(schedule), 6 * 60);
    });

    test('media gli orari diversi dei giorni lavorati', () {
      const schedule = WeekdaySchedule(
        monday: DaySchedule(targetMinutes: 480),
        tuesday: DaySchedule(targetMinutes: 240),
        wednesday: DaySchedule(targetMinutes: 0),
        thursday: DaySchedule(targetMinutes: 0),
        friday: DaySchedule(targetMinutes: 0),
        saturday: DaySchedule(targetMinutes: 0),
        sunday: DaySchedule(targetMinutes: 0),
      );

      expect(averageWorkingDayTargetMinutes(schedule), 360);
    });

    test('settimana senza ore previste vale zero', () {
      expect(
        averageWorkingDayTargetMinutes(
          WeekdaySchedule.uniform(8 * 60, workingDays: const {}),
        ),
        0,
      );
    });
  });
}
