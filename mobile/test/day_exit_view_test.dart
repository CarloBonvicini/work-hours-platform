import 'package:flutter_test/flutter_test.dart';
import 'package:work_hours_mobile/domain/models/day_schedule.dart';
import 'package:work_hours_mobile/domain/models/user_work_rules.dart';
import 'package:work_hours_mobile/domain/models/workday_session.dart';
import 'package:work_hours_mobile/presentation/home/logic/day_exit_view.dart';

const _schedule = DaySchedule(
  targetMinutes: 480,
  startTime: '08:15',
  breakMinutes: 60,
);

const _workRules = UserWorkRules(
  expectedDailyMinutes: 480,
  minimumBreakMinutes: 0,
  maximumDailyCreditMinutes: 0,
  maximumDailyDebitMinutes: 0,
  maximumMonthlyCreditMinutes: 0,
  maximumMonthlyDebitMinutes: 0,
);

DayExitView viewFor({
  WorkdaySession? session,
  String scheduledEndTimeText = '',
  int nowMinutes = (12 * 60) + 49,
  int? pendingConfirmationMinutes,
}) {
  return resolveDayExitView(
    effectiveSchedule: _schedule,
    quickEditorSchedule: _schedule,
    workRules: _workRules,
    scheduledEndTimeText: scheduledEndTimeText,
    rawStartTimeText: '08:15',
    rawEndTimeText: scheduledEndTimeText,
    isDayOff: false,
    isToday: true,
    hasResultContext: true,
    hasSuggestionContext: true,
    session: session,
    nowMinutes: nowMinutes,
    pendingConfirmationMinutes: pendingConfirmationMinutes,
  );
}

void main() {
  group('uscita prevista della giornata', () {
    test('la calcola da entrata, ore da fare e pausa', () {
      // 08:15 + 8:00 + 60 min.
      expect(viewFor().suggestedLabel, '17:15');
      expect(viewFor().suggestedTotalMinutes, (17 * 60) + 15);
    });

    test('una pausa piu lunga di quella prevista sposta l uscita', () {
      // La sessione tiene la pausa in due forme e l'app le scrive insieme:
      // il totale e i singoli intervalli.
      const session = WorkdaySession(
        startMinutes: (8 * 60) + 15,
        accumulatedBreakMinutes: 90,
        breakSegments: [
          WorkdayBreakSegment(
            startMinutes: (12 * 60),
            endMinutes: (13 * 60) + 30,
          ),
        ],
      );

      // 90 minuti di pausa fatta invece dei 60 previsti: si esce alle 17:45.
      expect(viewFor(session: session).suggestedLabel, '17:45');
    });

    test('una pausa piu corta non anticipa l uscita', () {
      const session = WorkdaySession(
        startMinutes: (8 * 60) + 15,
        accumulatedBreakMinutes: 20,
        breakSegments: [
          WorkdayBreakSegment(
            startMinutes: (12 * 60),
            endMinutes: (12 * 60) + 20,
          ),
        ],
      );

      expect(viewFor(session: session).suggestedLabel, '17:15');
    });

    test('senza orario registrato l uscita resta una previsione', () {
      final view = viewFor();

      expect(view.hasScheduledExit, isFalse);
      expect(view.isForecast, isTrue);
      expect(view.confirmableMinutes, (17 * 60) + 15);
    });

    test('con un uscita registrata non e piu una previsione', () {
      final view = viewFor(scheduledEndTimeText: '17:04');

      expect(view.hasScheduledExit, isTrue);
      expect(view.isForecast, isFalse);
    });

    test('dice quanto manca all uscita registrata', () {
      final view = viewFor(scheduledEndTimeText: '17:15');

      expect(view.remainingMinutes, (4 * 60) + 26);
      expect(view.remainingLabel, "Mancano 4:26 all'uscita prevista");
    });

    test('un uscita oltre la mezzanotte non e confermabile con un tocco', () {
      final view = viewFor(pendingConfirmationMinutes: (25 * 60));

      expect(view.hasPendingConfirmation, isTrue);
      expect(view.confirmableMinutes, isNull);
    });
  });
}
