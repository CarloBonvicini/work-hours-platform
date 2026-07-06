import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:work_hours_mobile/domain/models/workday_session.dart';

export 'package:work_hours_mobile/domain/models/workday_session.dart';

abstract class WorkdayStartStore {
  Future<WorkdaySession?> loadSession(String isoDate);

  Future<void> saveSession(String isoDate, WorkdaySession session);

  Future<void> clearSession(String isoDate);

  Future<Map<String, WorkdaySession>> exportAllSessions();

  Future<void> importSessions(Map<String, WorkdaySession> sessions);
}

class SharedPreferencesWorkdayStartStore implements WorkdayStartStore {
  const SharedPreferencesWorkdayStartStore();

  static const _keyPrefix = 'workday.session.';

  @override
  Future<void> clearSession(String isoDate) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove('$_keyPrefix$isoDate');
  }

  @override
  Future<WorkdaySession?> loadSession(String isoDate) async {
    final preferences = await SharedPreferences.getInstance();
    return WorkdaySession.fromJsonString(
      preferences.getString('$_keyPrefix$isoDate'),
    );
  }

  @override
  Future<void> saveSession(String isoDate, WorkdaySession session) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      '$_keyPrefix$isoDate',
      jsonEncode(session.toJson()),
    );
  }

  @override
  Future<Map<String, WorkdaySession>> exportAllSessions() async {
    final preferences = await SharedPreferences.getInstance();
    final sessionsByDate = <String, WorkdaySession>{};
    for (final key in preferences.getKeys()) {
      if (!key.startsWith(_keyPrefix)) {
        continue;
      }

      final isoDate = key.substring(_keyPrefix.length);
      final session = WorkdaySession.fromJsonString(preferences.getString(key));
      if (isoDate.isNotEmpty && session != null) {
        sessionsByDate[isoDate] = session;
      }
    }

    return sessionsByDate;
  }

  @override
  Future<void> importSessions(Map<String, WorkdaySession> sessions) async {
    for (final entry in sessions.entries) {
      await saveSession(entry.key, entry.value);
    }
  }
}
