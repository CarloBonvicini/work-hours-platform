import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:work_hours_mobile/application/services/dashboard_service.dart';
import 'package:work_hours_mobile/data/repositories/local_dashboard_repository.dart';
import 'package:work_hours_mobile/domain/models/monthly_expected_minutes.dart';

// Il profilo di partenza chiede 8 ore dal lunedi' al venerdi'. Settembre 2026
// comincia di martedi' e ha 22 feriali: 9 prima di lunedi' 14, lunedi' 14 e
// 12 dopo.
const _workdayMinutes = 480;

SharedPreferencesLocalDashboardRepository _repositoryAt(DateTime now) {
  return SharedPreferencesLocalDashboardRepository(now: () => now);
}

Future<void> _registerDay(
  SharedPreferencesLocalDashboardRepository repository,
  String date,
) {
  return repository.addWorkEntry(
    date: date,
    minutes: _workdayMinutes,
    month: date.substring(0, 7),
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'i giorni non ancora arrivati si vedono ma non pesano sul saldo',
    () async {
      final repository = _repositoryAt(DateTime(2026, 9, 14, 10));
      await _registerDay(repository, '2026-09-01');
      final snapshot = await repository.loadSnapshot(month: '2026-09');

      expect(snapshot.summary.expectedMinutes, 9 * _workdayMinutes);
      expect(snapshot.summary.remainingExpectedMinutes, 13 * _workdayMinutes);
      // Un giorno registrato su nove: gli altri otto sono debito. Prima era
      // -21 giorni, perche' contava anche la fine del mese.
      expect(snapshot.summary.rawBalanceMinutes, -8 * _workdayMinutes);
    },
  );

  test('oggi matura appena c e qualcosa di registrato', () async {
    final repository = _repositoryAt(DateTime(2026, 9, 14, 18));
    await _registerDay(repository, '2026-09-01');
    final snapshot = await repository.addWorkEntry(
      date: '2026-09-14',
      minutes: _workdayMinutes,
      month: '2026-09',
    );

    expect(snapshot.summary.expectedMinutes, 10 * _workdayMinutes);
    expect(snapshot.summary.remainingExpectedMinutes, 12 * _workdayMinutes);
  });

  test('chi comincia a meta mese non parte in debito', () async {
    final repository = _repositoryAt(DateTime(2026, 9, 14, 10));
    // Prima registrazione giovedi' 10: pesano solo il 10 e l'11.
    await _registerDay(repository, '2026-09-10');
    final snapshot = await repository.loadSnapshot(month: '2026-09');

    expect(snapshot.trackingStartDate, '2026-09-10');
    expect(snapshot.summary.expectedMinutes, 2 * _workdayMinutes);
    expect(snapshot.summary.rawBalanceMinutes, -1 * _workdayMinutes);
  });

  test('senza nessuna registrazione non c e ancora debito', () async {
    final snapshot = await _repositoryAt(
      DateTime(2026, 9, 14, 10),
    ).loadSnapshot(month: '2026-09');

    expect(snapshot.summary.expectedMinutes, 0);
    expect(snapshot.summary.rawBalanceMinutes, 0);
    expect(snapshot.summary.remainingExpectedMinutes, 13 * _workdayMinutes);
  });

  test('un mese gia passato matura tutto', () async {
    final repository = _repositoryAt(DateTime(2026, 9, 14, 10));
    // Agosto 2026 comincia di sabato: il 3 e' il primo feriale, 21 in tutto.
    await _registerDay(repository, '2026-08-03');
    final snapshot = await repository.loadSnapshot(month: '2026-08');

    expect(snapshot.summary.expectedMinutes, 21 * _workdayMinutes);
    expect(snapshot.summary.remainingExpectedMinutes, 0);
  });

  test(
    'toccare di nuovo gli orari aggiorna le ore invece di raddoppiarle',
    () async {
      final service = DashboardService(
        repository: _repositoryAt(DateTime(2026, 9, 14, 18)),
      );
      await service.upsertDayWorkedHours(
        date: '2026-09-11',
        minutes: 8 * 60,
        noteIfNew: 'Orario del giorno',
      );
      final snapshot = await service.upsertDayWorkedHours(
        date: '2026-09-11',
        minutes: 7 * 60 + 30,
        noteIfNew: 'Orario del giorno',
      );

      final dayEntries = snapshot.workEntries.where(
        (entry) => entry.date == '2026-09-11',
      );
      expect(dayEntries.map((entry) => entry.minutes), [7 * 60 + 30]);
    },
  );

  group('dayCountsInBalance', () {
    bool counts(String isoDate, {bool hasRegistrations = false}) {
      return dayCountsInBalance(
        isoDate: isoDate,
        todayIsoDate: '2026-09-14',
        trackingStartDate: '2026-09-10',
        hasRegistrations: hasRegistrations,
      );
    }

    test('un giorno passato vuoto pesa come debito', () {
      expect(counts('2026-09-11'), isTrue);
    });

    test('prima della prima registrazione non pesa', () {
      expect(counts('2026-09-09'), isFalse);
    });

    test('oggi pesa solo con qualcosa di registrato', () {
      expect(counts('2026-09-14'), isFalse);
      expect(counts('2026-09-14', hasRegistrations: true), isTrue);
    });

    test('il futuro non pesa', () {
      expect(counts('2026-09-15', hasRegistrations: true), isFalse);
    });
  });
}
