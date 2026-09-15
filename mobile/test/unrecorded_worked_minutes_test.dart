import 'package:flutter_test/flutter_test.dart';
import 'package:work_hours_mobile/domain/models/day_schedule.dart';
import 'package:work_hours_mobile/presentation/home/logic/unrecorded_worked_minutes.dart';

const _workedDay = DaySchedule(
  targetMinutes: 480,
  startTime: '08:15',
  endTime: '17:20',
);

int? resolveFor({
  bool isToday = false,
  bool isDayOff = false,
  int recordedWorkedMinutes = 0,
  DaySchedule schedule = _workedDay,
  int minimumBreakMinutes = 0,
}) {
  return resolveUnrecordedWorkedMinutes(
    isToday: isToday,
    isDayOff: isDayOff,
    recordedWorkedMinutes: recordedWorkedMinutes,
    schedule: schedule,
    minimumBreakMinutes: minimumBreakMinutes,
  );
}

void main() {
  group('ore presenti nell orario ma non registrate', () {
    test('un giorno passato con entrata e uscita ma zero ore le segnala', () {
      // Il caso della schermata: 08:15-17:20 e "Lavorate 0:00".
      expect(resolveFor(), (9 * 60) + 5);
    });

    test('la pausa si scala', () {
      expect(
        resolveFor(
          schedule: const DaySchedule(
            targetMinutes: 480,
            startTime: '08:15',
            endTime: '17:20',
            breakMinutes: 60,
          ),
        ),
        (8 * 60) + 5,
      );
    });

    test('se le ore sono gia registrate non c e niente da segnalare', () {
      expect(resolveFor(recordedWorkedMinutes: 480), isNull);
    });

    test('oggi non si segnala: la giornata e ancora in corso', () {
      expect(resolveFor(isToday: true), isNull);
    });

    test('una giornata libera non ha ore da registrare', () {
      expect(resolveFor(isDayOff: true), isNull);
    });

    test('senza uscita non si puo dire quante ore siano', () {
      expect(
        resolveFor(
          schedule: const DaySchedule(targetMinutes: 480, startTime: '08:15'),
        ),
        isNull,
      );
    });

    test('un orario che non produce ore non si segnala', () {
      expect(
        resolveFor(
          schedule: const DaySchedule(
            targetMinutes: 480,
            startTime: '09:00',
            endTime: '09:00',
          ),
        ),
        isNull,
      );
    });
  });
}
