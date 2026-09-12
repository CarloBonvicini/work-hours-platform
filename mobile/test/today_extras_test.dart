import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_hours_mobile/domain/models/day_schedule.dart';
import 'package:work_hours_mobile/domain/models/user_work_rules.dart';
import 'package:work_hours_mobile/domain/models/workday_session.dart';
import 'package:work_hours_mobile/presentation/home/models/activity_item.dart';
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

  group('TodayExtrasCard', () {
    Widget wrap(Widget child) {
      return MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: child)),
      );
    }

    const permitItem = ActivityItem(
      key: 'leave-l1',
      entryId: 'l1',
      kind: ActivityEntryKind.leave,
      date: '2026-09-11',
      title: 'Permesso',
      subtitle: 'Visita',
      minutes: 120,
      accentColor: Colors.orange,
      icon: Icons.event_available_outlined,
    );

    TodayExtrasCard buildCard({
      bool isToday = true,
      List<ActivityItem> dayActivities = const [],
      List<LeaveAllowanceSummary> allowances = const [],
      int expectedMinutes = 480,
      int workedMinutes = 300,
      int leaveMinutes = 0,
      bool hasProgressContext = true,
      int? remainingOvertimeMinutes,
      VoidCallback? onAddWork,
      VoidCallback? onAddLeave,
      ValueChanged<ActivityItem>? onEditActivity,
      ValueChanged<ActivityItem>? onDeleteActivity,
    }) {
      return TodayExtrasCard(
        isToday: isToday,
        dayActivities: dayActivities,
        allowances: allowances,
        expectedMinutes: expectedMinutes,
        workedMinutes: workedMinutes,
        leaveMinutes: leaveMinutes,
        hasProgressContext: hasProgressContext,
        remainingOvertimeMinutes: remainingOvertimeMinutes,
        onAddWork: onAddWork ?? () {},
        onAddLeave: onAddLeave ?? () {},
        onEditActivity: onEditActivity ?? (_) {},
        onDeleteActivity: onDeleteActivity ?? (_) {},
      );
    }

    testWidgets('mostra residui con nomi duplicati senza errori di chiave', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          buildCard(
            allowances: const [
              LeaveAllowanceSummary(name: 'Ferie', remainingLabel: '12 gg'),
              LeaveAllowanceSummary(name: 'Ferie', remainingLabel: '6:30'),
            ],
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Ferie: 12 gg'), findsOneWidget);
      expect(find.text('Ferie: 6:30'), findsOneWidget);
      expect(find.text('5:00 su 8:00 - mancano 3:00'), findsOneWidget);
      expect(find.text('Nessuna registrazione.'), findsOneWidget);
    });

    testWidgets(
      'elenca le registrazioni del giorno e il residuo straordinario',
      (tester) async {
        await tester.pumpWidget(
          wrap(
            buildCard(
              isToday: false,
              dayActivities: const [permitItem],
              workedMinutes: 420,
              leaveMinutes: 120,
              hasProgressContext: false,
              remainingOvertimeMinutes: 60,
            ),
          ),
        );

        expect(find.text('Registrazioni del giorno'), findsOneWidget);
        expect(find.text('Permesso'), findsOneWidget);
        expect(find.text('Visita'), findsOneWidget);
        expect(find.text('Obiettivo superato di 1:00'), findsOneWidget);
        expect(
          find.text('Straordinario ancora disponibile oggi: 1:00'),
          findsOneWidget,
        );
        expect(find.text('Residui'), findsNothing);
      },
    );

    testWidgets('offre modifica ed eliminazione per ogni registrazione', (
      tester,
    ) async {
      ActivityItem? edited;
      ActivityItem? deleted;
      var addWorkTaps = 0;
      await tester.pumpWidget(
        wrap(
          buildCard(
            dayActivities: const [permitItem],
            onAddWork: () => addWorkTaps += 1,
            onEditActivity: (item) => edited = item,
            onDeleteActivity: (item) => deleted = item,
          ),
        ),
      );

      await tester.tap(find.byKey(const ValueKey('today-add-work-chip')));
      expect(addWorkTaps, 1);

      await tester.tap(find.byKey(const ValueKey('activity-menu-leave-l1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('activity-edit-leave-l1')));
      await tester.pumpAndSettle();
      expect(edited?.entryId, 'l1');

      await tester.tap(find.byKey(const ValueKey('activity-menu-leave-l1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('activity-delete-leave-l1')));
      await tester.pumpAndSettle();
      expect(deleted?.entryId, 'l1');
    });
  });
}
