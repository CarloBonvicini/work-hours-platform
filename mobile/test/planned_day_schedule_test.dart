import 'package:flutter_test/flutter_test.dart';
import 'package:work_hours_mobile/domain/models/day_schedule.dart';
import 'package:work_hours_mobile/domain/models/weekday_schedule.dart';
import 'package:work_hours_mobile/presentation/home/logic/planned_day_schedule.dart';

void main() {
  group('resolvePlannedStartMinutes', () {
    test('usa la prima entrata dichiarata nella settimana', () {
      final weekdaySchedule = WeekdaySchedule.uniform(
        8 * 60,
        startTime: '08:30',
        endTime: '17:00',
        breakMinutes: 30,
      );

      expect(resolvePlannedStartMinutes(weekdaySchedule), (8 * 60) + 30);
    });

    test('ripiega sulle 09:00 se nessun giorno indica un orario', () {
      expect(
        resolvePlannedStartMinutes(WeekdaySchedule.uniform(8 * 60)),
        fallbackPlannedStartMinutes,
      );
    });
  });

  group('completePlannedDaySchedule', () {
    test('deriva entrata e uscita quando il piano ha solo le ore', () {
      final schedule = completePlannedDaySchedule(
        const DaySchedule(targetMinutes: 8 * 60, breakMinutes: 30),
        referenceStartMinutes: 9 * 60,
      );

      expect(schedule.startTime, '09:00');
      expect(schedule.endTime, '17:30');
      expect(schedule.targetMinutes, 8 * 60);
      expect(schedule.breakMinutes, 30);
    });

    test('deriva l entrata a ritroso quando esiste solo l uscita', () {
      final schedule = completePlannedDaySchedule(
        const DaySchedule(targetMinutes: 6 * 60, endTime: '18:00'),
        referenceStartMinutes: 9 * 60,
      );

      expect(schedule.startTime, '12:00');
      expect(schedule.endTime, '18:00');
    });

    test('lascia intatto un piano gia completo', () {
      const planned = DaySchedule(
        targetMinutes: 7 * 60,
        startTime: '07:00',
        endTime: '15:00',
        breakMinutes: 60,
      );

      final schedule = completePlannedDaySchedule(
        planned,
        referenceStartMinutes: 9 * 60,
      );

      expect(schedule.startTime, planned.startTime);
      expect(schedule.endTime, planned.endTime);
    });

    test('non inventa orari sulle giornate libere', () {
      final schedule = completePlannedDaySchedule(
        const DaySchedule(targetMinutes: 0),
        referenceStartMinutes: 9 * 60,
      );

      expect(schedule.startTime, isNull);
      expect(schedule.endTime, isNull);
      expect(schedule.targetMinutes, 0);
    });

    test('non sfora la mezzanotte con turni lunghi a fine giornata', () {
      final schedule = completePlannedDaySchedule(
        const DaySchedule(targetMinutes: 8 * 60),
        referenceStartMinutes: 22 * 60,
      );

      expect(schedule.startTime, '22:00');
      expect(schedule.endTime, '23:59');
    });
  });
}
