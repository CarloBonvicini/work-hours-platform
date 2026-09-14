import 'package:flutter_test/flutter_test.dart';
import 'package:work_hours_mobile/application/services/theme_preference_store.dart';
import 'package:work_hours_mobile/domain/models/day_schedule.dart';
import 'package:work_hours_mobile/presentation/home/logic/calendar_day_labels.dart';
import 'package:work_hours_mobile/presentation/home/logic/quick_day_insights.dart';
import 'package:work_hours_mobile/presentation/home/models/calendar_day.dart';
import 'package:work_hours_mobile/presentation/home/models/day_metrics.dart';

// Settembre 2026, oggi lunedi' 14. Prima registrazione giovedi' 10.
const _workdayMinutes = 480;
final _today = DateTime(2026, 9, 14);

CalendarDay _pastDay(int day, {int workedMinutes = 0, bool counts = true}) {
  return CalendarDay(
    date: DateTime(2026, 9, day),
    isoDate: '2026-09-${day.toString().padLeft(2, '0')}',
    expectedMinutes: _workdayMinutes,
    workedMinutes: workedMinutes,
    leaveMinutes: 0,
    hasOverride: false,
    isToday: false,
    isSelected: false,
    relation: CalendarDayRelation.past,
    primaryLabel: null,
    secondaryLabel: null,
    details: null,
    countsInBalance: counts,
  );
}

DayMetrics _pastMetrics(int day, {int workedMinutes = 0, bool counts = true}) {
  return DayMetrics(
    date: DateTime(2026, 9, day),
    expectedMinutes: _workdayMinutes,
    workedMinutes: workedMinutes,
    leaveMinutes: 0,
    rawBalanceMinutes: workedMinutes - _workdayMinutes,
    balanceMinutes: workedMinutes - _workdayMinutes,
    hasOverride: false,
    schedule: const DaySchedule(targetMinutes: _workdayMinutes),
    countsInBalance: counts,
  );
}

int _balance(
  DayBalanceAggregation aggregation, {
  List<CalendarDay> days = const [],
  List<DayMetrics> weekMetrics = const [],
}) {
  return buildDisplayedPeriodBalanceInfo(
    selectedDate: _today,
    days: days,
    weekMetrics: weekMetrics,
    aggregation: aggregation,
    liveExpectedMinutes: _workdayMinutes,
    liveWorkedMinutes: 0,
    liveLeaveMinutes: 0,
  ).balanceMinutes;
}

void main() {
  group('saldo della home', () {
    test('un giorno passato vuoto pesa come debito nel mese', () {
      // Prima la home lo saltava, mentre il consuntivo lo contava: due saldi.
      expect(
        _balance(
          DayBalanceAggregation.monthly,
          days: [
            _pastDay(9, counts: false),
            _pastDay(10, workedMinutes: _workdayMinutes),
            _pastDay(11),
          ],
        ),
        -_workdayMinutes,
      );
    });

    test('e anche nella settimana', () {
      expect(
        _balance(
          DayBalanceAggregation.weekly,
          weekMetrics: [
            _pastMetrics(9, counts: false),
            _pastMetrics(10, workedMinutes: _workdayMinutes),
            _pastMetrics(11),
          ],
        ),
        -_workdayMinutes,
      );
    });
  });

  group('calendario', () {
    const plan = DaySchedule(
      targetMinutes: _workdayMinutes,
      startTime: '08:00',
      endTime: '17:00',
      breakMinutes: 60,
    );

    test('un giorno passato da registrare lo dice', () {
      expect(
        buildCalendarDaySecondaryLabel(
          relation: CalendarDayRelation.past,
          workedMinutes: 0,
          leaveMinutes: 0,
          hasOverride: true,
          todayStatusLabel: null,
          needsRegistration: true,
        ),
        'Da registrare',
      );
    });

    test('l orario del piano non vale come ore fatte', () {
      // Prima la cella segnava "Lavorato: 8:00" su un giorno senza nulla.
      final details = buildCalendarDayDetails(
        relation: CalendarDayRelation.past,
        schedule: plan,
        workedMinutes: 0,
        leaveMinutes: 0,
        session: null,
      );
      expect(details?.workedMinutes, 0);
      expect(details?.pauseMinutes, 0);
    });
  });
}
