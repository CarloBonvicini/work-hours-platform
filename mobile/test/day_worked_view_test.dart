import 'package:flutter_test/flutter_test.dart';
import 'package:work_hours_mobile/domain/models/day_schedule.dart';
import 'package:work_hours_mobile/domain/models/user_work_rules.dart';
import 'package:work_hours_mobile/domain/models/workday_session.dart';
import 'package:work_hours_mobile/presentation/home/logic/day_worked_view.dart';
import 'package:work_hours_mobile/presentation/home/models/day_metrics.dart';

const _workRules = UserWorkRules(
  expectedDailyMinutes: 480,
  minimumBreakMinutes: 0,
  maximumDailyCreditMinutes: 0,
  maximumDailyDebitMinutes: 0,
  maximumMonthlyCreditMinutes: 0,
  maximumMonthlyDebitMinutes: 0,
);

const _base = DaySchedule(targetMinutes: 480, startTime: '09:00');

DayMetrics metricsWith({int workedMinutes = 0, int leaveMinutes = 0}) {
  return DayMetrics(
    date: DateTime(2026, 9, 14),
    expectedMinutes: 480,
    workedMinutes: workedMinutes,
    leaveMinutes: leaveMinutes,
    rawBalanceMinutes: 0,
    balanceMinutes: 0,
    hasOverride: true,
    schedule: const DaySchedule(
      targetMinutes: 480,
      startTime: '08:15',
      endTime: '17:20',
    ),
  );
}

DayWorkedView viewFor({
  DaySchedule? schedule,
  DayMetrics? dayMetrics,
  WorkdaySession? session,
  bool isToday = false,
  int nowMinutes = (12 * 60) + 49,
}) {
  return resolveDayWorkedView(
    quickEditorSchedule:
        schedule ??
        const DaySchedule(
          targetMinutes: 480,
          startTime: '08:15',
          endTime: '17:20',
        ),
    baseSchedule: _base,
    workRules: _workRules,
    dayMetrics: dayMetrics ?? metricsWith(),
    session: session,
    pauseWindow: null,
    rawStartTimeText: '',
    rawEndTimeText: '',
    isToday: isToday,
    nowMinutes: nowMinutes,
  );
}

void main() {
  group('giorno passato con orario ma senza ore registrate', () {
    test('le ore mostrate restano zero: il piano non e una registrazione', () {
      expect(viewFor().workedMinutes, 0);
      expect(viewFor().hasResultContext, isFalse);
    });

    test('ma dice quante ore ci sarebbero da registrare', () {
      // Il caso della schermata: 08:15-17:20 senza ore registrate.
      expect(viewFor().unrecordedMinutes, (9 * 60) + 5);
    });
  });

  group('giorno passato con ore registrate', () {
    test('mostra le ore registrate', () {
      final view = viewFor(dayMetrics: metricsWith(workedMinutes: 485));

      expect(view.workedMinutes, 485);
      expect(view.hasResultContext, isTrue);
    });

    test('non segnala niente da registrare', () {
      expect(
        viewFor(dayMetrics: metricsWith(workedMinutes: 485)).unrecordedMinutes,
        isNull,
      );
    });
  });

  test('un permesso registrato basta a dare contesto alla giornata', () {
    expect(viewFor(dayMetrics: metricsWith(leaveMinutes: 60)).hasResultContext,
        isTrue);
  });

  test('oggi con la timbratura aperta conta il tempo passato', () {
    const session = WorkdaySession(startMinutes: (8 * 60) + 15);
    final view = viewFor(session: session, isToday: true);

    expect(view.hasResultContext, isTrue);
    expect(view.workedMinutes, (4 * 60) + 34);
    // Oggi non si segnala niente da registrare: la giornata e' in corso.
    expect(view.unrecordedMinutes, isNull);
  });

  test('una giornata libera non ha ore ne segnalazioni', () {
    final view = viewFor(
      schedule: const DaySchedule(targetMinutes: 0),
    );

    expect(view.isDayOff, isTrue);
    expect(view.workedMinutes, 0);
    expect(view.unrecordedMinutes, isNull);
  });
}
