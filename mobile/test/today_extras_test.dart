import 'package:flutter_test/flutter_test.dart';
import 'package:work_hours_mobile/domain/models/day_schedule.dart';
import 'package:work_hours_mobile/domain/models/user_work_rules.dart';
import 'package:work_hours_mobile/domain/models/workday_session.dart';
import 'package:work_hours_mobile/presentation/home/today_extras.dart';

void main() {
  group('buildLeaveAllowanceSummaries', () {
    test('include solo le regole attive con nome', () {
      final rules = UserWorkRules.unbounded(expectedDailyMinutes: 480).copyWith(
        leaveBanks: const [
          WorkPermissionRule(
            id: 'ferie',
            name: 'Ferie',
            enabled: true,
            period: WorkAllowancePeriod.yearly,
            allowanceType: WorkPermissionAllowanceType.days,
            allowanceDays: 20,
            usedDays: 8,
            movements: [],
          ),
          WorkPermissionRule(
            id: 'off',
            name: 'Disattivata',
            enabled: false,
            period: WorkAllowancePeriod.monthly,
            movements: [],
          ),
        ],
        additionalPermissions: const [
          WorkPermissionRule(
            id: 'rol',
            name: 'ROL',
            enabled: true,
            period: WorkAllowancePeriod.monthly,
            allowanceMinutes: 8 * 60,
            usedMinutes: 90,
            movements: [],
          ),
        ],
      );

      final summaries = buildLeaveAllowanceSummaries(rules);

      expect(summaries, hasLength(2));
      expect(summaries[0].name, 'Ferie');
      expect(summaries[0].remainingLabel, '12 gg');
      expect(summaries[1].name, 'ROL');
      expect(summaries[1].remainingLabel, '6:30');
    });

    test('non supera mai il monte ore anche con usato oltre soglia', () {
      final rules = UserWorkRules.unbounded(expectedDailyMinutes: 480).copyWith(
        leaveBanks: const [
          WorkPermissionRule(
            id: 'permessi',
            name: 'Permessi',
            enabled: true,
            period: WorkAllowancePeriod.yearly,
            allowanceMinutes: 120,
            usedMinutes: 999,
            movements: [],
          ),
        ],
      );

      expect(buildLeaveAllowanceSummaries(rules).single.remainingLabel, '0:00');
    });
  });

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
        formatWorkdayBreakSegments(session, (16 * 60) + 5),
        'Pause: 12:30-13:00 · 16:00-in corso',
      );
    });

    test('restituisce null senza pause', () {
      const session = WorkdaySession(startMinutes: 8 * 60);
      expect(formatWorkdayBreakSegments(session, 9 * 60), isNull);
      expect(formatWorkdayBreakSegments(null, 9 * 60), isNull);
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

  group('resolveRemainingDailyOvertimeMinutes', () {
    test('calcola il residuo rispetto al massimale giornaliero', () {
      final rules = UserWorkRules.unbounded(expectedDailyMinutes: 480).copyWith(
        overtimeEnabled: true,
        overtimeCapEnabled: true,
        overtimeDailyCapMinutes: 120,
      );

      expect(
        resolveRemainingDailyOvertimeMinutes(
          workRules: rules,
          rawBalanceMinutes: 45,
        ),
        75,
      );
      expect(
        resolveRemainingDailyOvertimeMinutes(
          workRules: rules,
          rawBalanceMinutes: -30,
        ),
        120,
      );
      expect(
        resolveRemainingDailyOvertimeMinutes(
          workRules: rules,
          rawBalanceMinutes: 300,
        ),
        0,
      );
    });

    test('null senza massimale attivo', () {
      expect(
        resolveRemainingDailyOvertimeMinutes(
          workRules: UserWorkRules.unbounded(expectedDailyMinutes: 480),
          rawBalanceMinutes: 60,
        ),
        isNull,
      );
    });
  });
}
