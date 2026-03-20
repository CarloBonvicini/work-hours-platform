import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class WorkdayBreakSegment {
  const WorkdayBreakSegment({
    required this.startMinutes,
    required this.endMinutes,
  });

  final int startMinutes;
  final int endMinutes;

  Map<String, dynamic> toJson() {
    return {
      'startMinutes': startMinutes,
      'endMinutes': endMinutes,
    };
  }

  static WorkdayBreakSegment? fromJson(Object? rawValue) {
    if (rawValue is! Map<String, dynamic>) {
      return null;
    }

    final startMinutes = rawValue['startMinutes'];
    final endMinutes = rawValue['endMinutes'];
    if (startMinutes is! int || endMinutes is! int || endMinutes <= startMinutes) {
      return null;
    }

    return WorkdayBreakSegment(
      startMinutes: startMinutes,
      endMinutes: endMinutes,
    );
  }
}

class WorkdaySession {
  const WorkdaySession({
    required this.startMinutes,
    this.breakStartedMinutes,
    this.accumulatedBreakMinutes = 0,
    this.breakSegments = const [],
    this.endMinutes,
  });

  final int startMinutes;
  final int? breakStartedMinutes;
  final int accumulatedBreakMinutes;
  final List<WorkdayBreakSegment> breakSegments;
  final int? endMinutes;

  bool get isOnBreak => breakStartedMinutes != null && endMinutes == null;
  bool get isCompleted => endMinutes != null;

  WorkdaySession copyWith({
    int? startMinutes,
    Object? breakStartedMinutes = _noValue,
    int? accumulatedBreakMinutes,
    List<WorkdayBreakSegment>? breakSegments,
    Object? endMinutes = _noValue,
  }) {
    return WorkdaySession(
      startMinutes: startMinutes ?? this.startMinutes,
      breakStartedMinutes: breakStartedMinutes == _noValue
          ? this.breakStartedMinutes
          : breakStartedMinutes as int?,
      accumulatedBreakMinutes:
          accumulatedBreakMinutes ?? this.accumulatedBreakMinutes,
      breakSegments: breakSegments ?? this.breakSegments,
      endMinutes: endMinutes == _noValue ? this.endMinutes : endMinutes as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'startMinutes': startMinutes,
      'breakStartedMinutes': breakStartedMinutes,
      'accumulatedBreakMinutes': accumulatedBreakMinutes,
      'breakSegments': breakSegments.map((segment) => segment.toJson()).toList(),
      'endMinutes': endMinutes,
    };
  }

  static WorkdaySession? fromJsonString(String? rawValue) {
    if (rawValue == null || rawValue.trim().isEmpty) {
      return null;
    }

    final decoded = jsonDecode(rawValue);
    if (decoded is! Map<String, dynamic>) {
      return null;
    }

    final startMinutes = decoded['startMinutes'];
    if (startMinutes is! int) {
      return null;
    }

    final breakSegmentsRaw = decoded['breakSegments'];
    final breakSegments = breakSegmentsRaw is List
        ? breakSegmentsRaw
              .map(WorkdayBreakSegment.fromJson)
              .whereType<WorkdayBreakSegment>()
              .toList(growable: false)
        : const <WorkdayBreakSegment>[];

    return WorkdaySession(
      startMinutes: startMinutes,
      breakStartedMinutes: decoded['breakStartedMinutes'] as int?,
      accumulatedBreakMinutes:
          (decoded['accumulatedBreakMinutes'] as int?) ?? 0,
      breakSegments: breakSegments,
      endMinutes: decoded['endMinutes'] as int?,
    );
  }
}

abstract class WorkdayStartStore {
  Future<WorkdaySession?> loadSession(String isoDate);

  Future<void> saveSession(String isoDate, WorkdaySession session);

  Future<void> clearSession(String isoDate);
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
}

const _noValue = Object();
