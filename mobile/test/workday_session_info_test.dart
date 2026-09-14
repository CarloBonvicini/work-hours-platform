import 'package:flutter_test/flutter_test.dart';
import 'package:work_hours_mobile/domain/models/day_schedule.dart';
import 'package:work_hours_mobile/domain/models/user_work_rules.dart';
import 'package:work_hours_mobile/domain/models/workday_session.dart';
import 'package:work_hours_mobile/presentation/home/logic/agenda_segments.dart';
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
        resolveWorkedSessionInfo(session: null, nowMinutes: 14 * 60),
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
        resolveWorkedSessionInfo(session: session, nowMinutes: 18 * 60),
        'Lavoro 7:30 | Pausa 0:30.',
      );
    });

    test('a meta giornata conta il tempo passato, non la giornata prevista', () {
      // Entrato alle 08:15, nessuna pausa, sono le 12:49. L'orario del giorno
      // arriva fino all'uscita prevista con un'ora di pausa: prima il riquadro
      // lo misurava tutto e diceva "Lavoro 8:00 | Pausa 1:00".
      const session = WorkdaySession(startMinutes: 8 * 60 + 15);
      expect(
        resolveWorkedSessionInfo(session: session, nowMinutes: 12 * 60 + 49),
        'Lavoro 4:34 | Pausa 0:00.',
      );
    });
  });

  group('resolveDisplayedSessionSchedule', () {
    // Solo le ore: l'uscita nasce dal conto.
    const hoursOnly = DaySchedule(targetMinutes: 8 * 60, breakMinutes: 30);
    // Piano 08:00-17:00 con un'ora di pausa.
    const plan = DaySchedule(
      targetMinutes: 8 * 60,
      startTime: '08:00',
      endTime: '17:00',
      breakMinutes: 60,
    );
    const lateEntry = WorkdaySession(startMinutes: 8 * 60 + 15);
    final rules = UserWorkRules.unbounded(expectedDailyMinutes: 8 * 60);

    String? endOf({
      required DaySchedule schedule,
      required WorkdaySession session,
      UserWorkRules? workRules,
      DaySchedule? baseSchedule,
    }) {
      return resolveDisplayedSessionSchedule(
        schedule: schedule,
        baseSchedule: baseSchedule ?? schedule,
        session: session,
        nowMinutes: 10 * 60,
        workRules: workRules,
      ).endTime;
    }

    test(
      'la pausa minima delle regole sposta l uscita come nella modifica rapida',
      () {
        // Prima questa copia ignorava la pausa minima: 16:45 invece di 17:15.
        expect(
          endOf(
            schedule: hoursOnly,
            session: lateEntry,
            workRules: UserWorkRules.unbounded(
              expectedDailyMinutes: 8 * 60,
              minimumBreakMinutes: 60,
            ),
          ),
          '17:15',
        );
      },
    );

    test('un uscita scritta a mano resta com e', () {
      expect(
        endOf(
          schedule: const DaySchedule(
            targetMinutes: 8 * 60,
            startTime: '08:00',
            endTime: '16:00',
            breakMinutes: 60,
          ),
          baseSchedule: plan,
          session: lateEntry,
          workRules: rules,
        ),
        '16:00',
      );
    });

    test(
      'oltre la mezzanotte si ferma alle 23:59 invece di ripartire da 0',
      () {
        expect(
          endOf(
            schedule: hoursOnly,
            session: const WorkdaySession(startMinutes: 18 * 60),
          ),
          '23:59',
        );
      },
    );

    test('senza orario fisso chi entra tardi esce tardi', () {
      // Prima restava l'uscita del piano: 17:00, con 15 minuti di debito
      // scoperti solo a fine giornata.
      expect(
        endOf(schedule: plan, session: lateEntry, workRules: rules),
        '17:15',
      );
    });

    test('con orario fisso si esce all ora del piano', () {
      expect(
        endOf(
          schedule: plan,
          session: lateEntry,
          workRules: rules.copyWith(fixedScheduleEnabled: true),
        ),
        '17:00',
      );
    });

    test('con la flessibilita l uscita segue l entrata dentro la fascia', () {
      final flexible = rules.copyWith(
        fixedScheduleEnabled: true,
        flexibleStartEnabled: true,
        flexibleStartWindowMinutes: 2 * 60,
      );
      expect(
        endOf(schedule: plan, session: lateEntry, workRules: flexible),
        '17:15',
      );
      // Oltre la fascia (08:00-10:00) l'uscita si ferma: il resto e' debito.
      expect(
        endOf(
          schedule: plan,
          session: const WorkdaySession(startMinutes: 10 * 60 + 30),
          workRules: flexible,
        ),
        '19:00',
      );
    });
  });

  group('buildAgendaWorkedSummary', () {
    const plannedSegments = [
      AgendaMeasurementSegment(
        startMinutes: 9 * 60,
        endMinutes: 13 * 60,
        label: '',
        kind: AgendaMeasurementSegmentKind.work,
      ),
      AgendaMeasurementSegment(
        startMinutes: 13 * 60,
        endMinutes: 14 * 60,
        label: '',
        kind: AgendaMeasurementSegmentKind.pause,
      ),
    ];

    test('il piano si presenta come previsione, non come ore lavorate', () {
      expect(
        buildAgendaWorkedSummary(
          measurementSegments: plannedSegments,
          isForecast: true,
        ),
        'Previsto: 4:00 lavoro | 1:00 pausa',
      );
    });

    test('la timbratura resta un totale di ore lavorate', () {
      expect(
        buildAgendaWorkedSummary(measurementSegments: plannedSegments),
        'Totale: 4:00 lavorate | 1:00 pausa',
      );
    });
  });
}
