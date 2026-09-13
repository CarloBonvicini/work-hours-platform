import 'package:flutter_test/flutter_test.dart';
import 'package:work_hours_mobile/domain/models/weekday_schedule.dart';
import 'package:work_hours_mobile/domain/models/weekday_target_minutes.dart';

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
      final schedule = WeekdaySchedule.uniform(
        8 * 60,
        workingDays: const {},
      );

      for (final weekday in WeekdayKey.values) {
        expect(schedule.forWeekday(weekday).targetMinutes, 0);
      }
    });
  });
}
