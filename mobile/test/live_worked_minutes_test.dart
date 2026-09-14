import 'package:flutter_test/flutter_test.dart';
import 'package:work_hours_mobile/domain/models/day_schedule.dart';
import 'package:work_hours_mobile/domain/models/user_work_rules.dart';
import 'package:work_hours_mobile/domain/models/workday_session.dart';
import 'package:work_hours_mobile/presentation/home/logic/agenda_segments.dart';
import 'package:work_hours_mobile/presentation/home/logic/day_balance.dart';

const _workRules = UserWorkRules(
  expectedDailyMinutes: 480,
  minimumBreakMinutes: 0,
  maximumDailyCreditMinutes: 0,
  maximumDailyDebitMinutes: 0,
  maximumMonthlyCreditMinutes: 0,
  maximumMonthlyDebitMinutes: 0,
);

int workedAt({
  required WorkdaySession session,
  required int nowMinutes,
  String? endTime,
  int breakMinutes = 60,
}) {
  final schedule = DaySchedule(
    targetMinutes: 480,
    startTime: '08:15',
    endTime: endTime,
    breakMinutes: breakMinutes,
  );
  return resolveLiveWorkedMinutes(
    quickEditorSchedule: schedule,
    workRules: _workRules,
    session: session,
    pauseWindow: resolveCalendarPauseWindow(
      schedule: schedule,
      startMinutes: 8 * 60 + 15,
      endMinutes: endTime == null ? null : 17 * 60 + 15,
      session: session,
      nowMinutes: nowMinutes,
    ),
    nowMinutes: nowMinutes,
  );
}

void main() {
  group('ore lavorate con la giornata in corso', () {
    const session = WorkdaySession(startMinutes: 8 * 60 + 15);
    const nowMinutes = (12 * 60) + 49;

    test('a meta giornata conta il tempo passato, non quello previsto', () {
      // Entrato alle 08:15, sono le 12:49: 4:34 di presenza.
      expect(workedAt(session: session, nowMinutes: nowMinutes), (4 * 60) + 34);
    });

    test('l uscita prevista non vale come ora gia lavorata', () {
      // Con l'uscita prevista delle 17:15 scritta nel giorno il conto diceva
      // 8:00 alle 12:49: la previsione era diventata un fatto.
      expect(
        workedAt(
          session: session,
          nowMinutes: nowMinutes,
          endTime: '17:15',
        ),
        (4 * 60) + 34,
      );
    });

    test('la pausa registrata si scala dalle ore lavorate', () {
      const sessionWithBreak = WorkdaySession(
        startMinutes: 8 * 60 + 15,
        breakSegments: [
          WorkdayBreakSegment(
            startMinutes: (12 * 60) + 0,
            endMinutes: (12 * 60) + 30,
          ),
        ],
      );

      expect(
        workedAt(
          session: sessionWithBreak,
          nowMinutes: nowMinutes,
          endTime: '17:15',
        ),
        (4 * 60) + 4,
      );
    });

    test('a giornata chiusa conta fino all uscita timbrata', () {
      const closedSession = WorkdaySession(
        startMinutes: 8 * 60 + 15,
        endMinutes: (17 * 60) + 20,
      );

      expect(
        workedAt(
          session: closedSession,
          nowMinutes: nowMinutes,
          endTime: '17:15',
        ),
        (9 * 60) + 5,
      );
    });
  });
}
