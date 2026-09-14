import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:work_hours_mobile/data/repositories/local_dashboard_repository.dart';

// Il profilo di partenza chiede 8 ore dal lunedi' al venerdi'. Settembre 2026
// comincia di martedi' e ha 22 feriali: 9 prima di lunedi' 14, lunedi' 14 e
// 12 dopo.
const _workdayMinutes = 480;

SharedPreferencesLocalDashboardRepository _repositoryAt(DateTime now) {
  return SharedPreferencesLocalDashboardRepository(now: () => now);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'i giorni non ancora arrivati si vedono ma non pesano sul saldo',
    () async {
      final snapshot = await _repositoryAt(
        DateTime(2026, 9, 14, 10),
      ).loadSnapshot(month: '2026-09');

      expect(snapshot.summary.expectedMinutes, 9 * _workdayMinutes);
      expect(snapshot.summary.remainingExpectedMinutes, 13 * _workdayMinutes);
      // Prima era -22 giorni: anche le ore di fine mese contavano come debito.
      expect(snapshot.summary.rawBalanceMinutes, -9 * _workdayMinutes);
    },
  );

  test('oggi matura appena c e qualcosa di registrato', () async {
    final snapshot = await _repositoryAt(DateTime(2026, 9, 14, 18))
        .addWorkEntry(
          date: '2026-09-14',
          minutes: _workdayMinutes,
          month: '2026-09',
        );

    expect(snapshot.summary.expectedMinutes, 10 * _workdayMinutes);
    expect(snapshot.summary.remainingExpectedMinutes, 12 * _workdayMinutes);
  });

  test('un mese gia passato matura tutto', () async {
    // Agosto 2026 ha 21 feriali.
    final snapshot = await _repositoryAt(
      DateTime(2026, 9, 14, 10),
    ).loadSnapshot(month: '2026-08');

    expect(snapshot.summary.expectedMinutes, 21 * _workdayMinutes);
    expect(snapshot.summary.remainingExpectedMinutes, 0);
  });
}
