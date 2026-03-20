import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:work_hours_mobile/domain/models/account_session.dart';

abstract class AccountSessionStore {
  Future<AccountSession?> loadSession();

  Future<void> saveSession(AccountSession session);

  Future<void> clearSession();
}

class SharedPreferencesAccountSessionStore implements AccountSessionStore {
  const SharedPreferencesAccountSessionStore();

  static const _sessionKey = 'account.session';

  @override
  Future<AccountSession?> loadSession() async {
    final preferences = await SharedPreferences.getInstance();
    final rawValue = preferences.getString(_sessionKey);
    if (rawValue == null || rawValue.trim().isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(rawValue);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      return AccountSession.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> saveSession(AccountSession session) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_sessionKey, jsonEncode(session.toJson()));
  }

  @override
  Future<void> clearSession() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_sessionKey);
  }
}
