import 'package:flutter_test/flutter_test.dart';
import 'package:work_hours_mobile/presentation/home/logic/calendar_dates.dart';
import 'package:work_hours_mobile/presentation/home/models/calendar_view.dart';

void main() {
  group('addCalendarDays', () {
    test(
      'avanza di un giorno di calendario anche nel giorno lungo di ottobre',
      () {
        // Il 25/10/2026 in Italia dura 25 ore: +24h resterebbe sul 25.
        final next = addCalendarDays(DateTime(2026, 10, 25), 1);
        expect((next.year, next.month, next.day, next.hour), (2026, 10, 26, 0));
      },
    );

    test(
      'torna indietro di un giorno senza saltare il giorno del cambio ora',
      () {
        final previous = addCalendarDays(DateTime(2026, 10, 26), -1);
        expect((previous.month, previous.day, previous.hour), (10, 25, 0));
      },
    );

    test('resta a mezzanotte nel giorno corto di marzo', () {
      final next = addCalendarDays(DateTime(2026, 3, 29), 1);
      expect((next.month, next.day, next.hour), (3, 30, 0));
    });

    test('attraversa mese e anno', () {
      final next = addCalendarDays(DateTime(2026, 12, 31), 1);
      expect((next.year, next.month, next.day), (2027, 1, 1));
      final previous = addCalendarDays(DateTime(2028, 3, 1), -1);
      expect((previous.year, previous.month, previous.day), (2028, 2, 29));
    });
  });

  group('shiftCalendarPeriodDate', () {
    final selected = DateTime(2026, 10, 25);

    test('giorno e settimana usano giorni di calendario', () {
      final day = shiftCalendarPeriodDate(selected, CalendarView.day, 1);
      expect((day.month, day.day, day.hour), (10, 26, 0));
      final week = shiftCalendarPeriodDate(selected, CalendarView.week, 1);
      expect((week.month, week.day, week.hour), (11, 1, 0));
    });

    test('mese e anno portano al primo del periodo', () {
      final month = shiftCalendarPeriodDate(
        DateTime(2026, 1, 31),
        CalendarView.month,
        1,
      );
      expect((month.year, month.month, month.day), (2026, 2, 1));
      final backMonth = shiftCalendarPeriodDate(
        DateTime(2026, 1, 15),
        CalendarView.month,
        -1,
      );
      expect((backMonth.year, backMonth.month, backMonth.day), (2025, 12, 1));
      final year = shiftCalendarPeriodDate(
        DateTime(2026, 2, 29 - 1),
        CalendarView.year,
        1,
      );
      expect((year.year, year.month, year.day), (2027, 2, 1));
    });
  });
}
