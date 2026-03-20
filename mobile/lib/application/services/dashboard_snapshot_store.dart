import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:work_hours_mobile/domain/models/dashboard_snapshot.dart';

abstract class DashboardSnapshotStore {
  Future<DashboardSnapshot?> loadSnapshot(String month);

  Future<void> saveSnapshot(DashboardSnapshot snapshot);

  Future<void> removeSnapshot(String month);
}

class InMemoryDashboardSnapshotStore implements DashboardSnapshotStore {
  const InMemoryDashboardSnapshotStore();

  static final Map<String, DashboardSnapshot> _snapshots = {};

  @override
  Future<DashboardSnapshot?> loadSnapshot(String month) async {
    return _snapshots[month];
  }

  @override
  Future<void> removeSnapshot(String month) async {
    _snapshots.remove(month);
  }

  @override
  Future<void> saveSnapshot(DashboardSnapshot snapshot) async {
    _snapshots[snapshot.summary.month] = snapshot;
  }
}

class SharedPreferencesDashboardSnapshotStore
    implements DashboardSnapshotStore {
  const SharedPreferencesDashboardSnapshotStore();

  static const _keyPrefix = 'dashboard.snapshot.';

  @override
  Future<DashboardSnapshot?> loadSnapshot(String month) async {
    final preferences = await SharedPreferences.getInstance();
    final rawSnapshot = preferences.getString('$_keyPrefix$month');
    if (rawSnapshot == null || rawSnapshot.trim().isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(rawSnapshot);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      return DashboardSnapshot.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> removeSnapshot(String month) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove('$_keyPrefix$month');
  }

  @override
  Future<void> saveSnapshot(DashboardSnapshot snapshot) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      '$_keyPrefix${snapshot.summary.month}',
      jsonEncode(snapshot.toJson()),
    );
  }
}
