import 'package:flutter_test/flutter_test.dart';
import 'package:work_hours_mobile/domain/models/day_schedule.dart';
import 'package:work_hours_mobile/domain/models/user_work_rules.dart';
import 'package:work_hours_mobile/domain/models/workday_session.dart';
import 'package:work_hours_mobile/presentation/home/logic/workday_session_info.dart';

void main() {
  group('formatWorkdayBreakSegments', () {
    test('elenca i segmenti chiusi e la pausa in corso', () {
      const session = WorkdaySession(
        startMinutes: 8 * 60,
        breakStartedMinutes: 16 * 60,
        accumulatedBreakMinutes: 30,
        breakSegments: [
          WorkdayBreakSegment(startMinutes: 12 * 60 + 30, endMinutes: 13 * 60),
        ],
      );

      expect(
        formatWorkdayBreakSegments(session),
        'Pause: 12:30-13:00 · 16:00-in corso',
      );
    });

    test('restituisce null senza pause', () {
      const session = WorkdaySession(startMinutes: 8 * 60);
      expect(formatWorkdayBreakSegments(session), isNull);
      expect(formatWorkdayBreakSegments(null), isNull);
    });
  });

  group('resolveFlexibleEntryWindowLabel', () {
    test('mostra la fascia quando flessibilita e orario fisso sono attivi', () {
      final rules = UserWorkRules.unbounded(expectedDailyMinutes: 480).copyWith(
        fixedScheduleEnabled: true,
        flexibleStartEnabled: true,
        flexibleStartWindowMinutes: 120,
      );

      expect(
        resolveFlexibleEntryWindowLabel(
          workRules: rules,
          schedule: const DaySchedule(targetMinutes: 480, startTime: '07:30'),
        ),
        'Fascia d ingresso: 07:30 - 09:30',
      );
    });

    test('null quando la flessibilita e spenta o manca l orario', () {
      final rules = UserWorkRules.unbounded(expectedDailyMinutes: 480).copyWith(
        fixedScheduleEnabled: true,
        flexibleStartEnabled: true,
        flexibleStartWindowMinutes: 120,
      );

      expect(
        resolveFlexibleEntryWindowLabel(
          workRules: UserWorkRules.unbounded(expectedDailyMinutes: 480),
          schedule: const DaySchedule(targetMinutes: 480, startTime: '07:30'),
        ),
        isNull,
      );
      expect(
        resolveFlexibleEntryWindowLabel(
          workRules: rules,
          schedule: const DaySchedule(targetMinutes: 480),
        ),
        isNull,
      );
    });
  });

  group('resolveWorkedSessionInfo', () {
    test('senza timbratura non riporta ore lavorate', () {
      expect(
        resolveWorkedSessionInfo(
          session: null,
          // Orario previsto completo: resta una previsione, non ore lavorate.
          schedule: const DaySchedule(
            targetMinutes: 8 * 60,
            startTime: '09:00',
            endTime: '17:00',
          ),
          pauseWindow: null,
          nowMinutes: 14 * 60,
        ),
        isNull,
      );
    });

    test('con timbratura chiusa riporta lavoro e pausa', () {
      const session = WorkdaySession(
        startMinutes: 9 * 60,
        endMinutes: 17 * 60,
        accumulatedBreakMinutes: 30,
        breakSegments: [
          WorkdayBreakSegment(startMinutes: 13 * 60, endMinutes: 13 * 60 + 30),
        ],
      );

      expect(
        resolveWorkedSessionInfo(
          session: session,
          schedule: const DaySchedule(
            targetMinutes: 8 * 60,
            startTime: '09:00',
            endTime: '17:00',
          ),
          pauseWindow: null,
          nowMinutes: 18 * 60,
        ),
        'Lavoro 7:30 | Pausa 0:30.',
      );
    });
  });
}
