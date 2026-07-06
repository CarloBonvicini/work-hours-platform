import 'package:work_hours_mobile/application/services/theme_preference_store.dart';
import 'package:work_hours_mobile/domain/models/leave_entry.dart';
import 'package:work_hours_mobile/domain/models/profile.dart';
import 'package:work_hours_mobile/domain/models/schedule_override.dart';
import 'package:work_hours_mobile/domain/models/work_entry.dart';
import 'package:work_hours_mobile/domain/models/workday_session.dart';

Map<String, WorkdaySession> _parseWorkdaySessions(Object? rawValue) {
  if (rawValue is! Map<String, dynamic>) {
    return const {};
  }

  final sessionsByDate = <String, WorkdaySession>{};
  for (final entry in rawValue.entries) {
    final session = WorkdaySession.fromJson(entry.value);
    if (entry.key.isNotEmpty && session != null) {
      sessionsByDate[entry.key] = session;
    }
  }

  return sessionsByDate;
}

Map<String, dynamic> _workdaySessionsToJson(
  Map<String, WorkdaySession> sessions,
) {
  return {
    for (final entry in sessions.entries) entry.key: entry.value.toJson(),
  };
}

class LocalDashboardDataBundle {
  const LocalDashboardDataBundle({
    required this.profile,
    required this.workEntries,
    required this.leaveEntries,
    required this.scheduleOverrides,
    this.workdaySessions = const {},
  });

  final UserProfile profile;
  final List<WorkEntry> workEntries;
  final List<LeaveEntry> leaveEntries;
  final List<ScheduleOverride> scheduleOverrides;
  final Map<String, WorkdaySession> workdaySessions;

  factory LocalDashboardDataBundle.fromJson(Map<String, dynamic> json) {
    return LocalDashboardDataBundle(
      profile: UserProfile.fromJson(json['profile'] as Map<String, dynamic>),
      workEntries: (json['workEntries'] as List<dynamic>? ?? const [])
          .map((item) => WorkEntry.fromJson(item as Map<String, dynamic>))
          .toList(growable: false),
      leaveEntries: (json['leaveEntries'] as List<dynamic>? ?? const [])
          .map((item) => LeaveEntry.fromJson(item as Map<String, dynamic>))
          .toList(growable: false),
      scheduleOverrides:
          (json['scheduleOverrides'] as List<dynamic>? ?? const [])
              .map(
                (item) =>
                    ScheduleOverride.fromJson(item as Map<String, dynamic>),
              )
              .toList(growable: false),
      workdaySessions: _parseWorkdaySessions(json['workdaySessions']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'profile': profile.toJson(),
      'workEntries': workEntries.map((entry) => entry.toJson()).toList(),
      'leaveEntries': leaveEntries.map((entry) => entry.toJson()).toList(),
      'scheduleOverrides': scheduleOverrides
          .map((entry) => entry.toJson())
          .toList(),
      'workdaySessions': _workdaySessionsToJson(workdaySessions),
    };
  }

  LocalDashboardDataBundle copyWith({
    Map<String, WorkdaySession>? workdaySessions,
  }) {
    return LocalDashboardDataBundle(
      profile: profile,
      workEntries: workEntries,
      leaveEntries: leaveEntries,
      scheduleOverrides: scheduleOverrides,
      workdaySessions: workdaySessions ?? this.workdaySessions,
    );
  }
}

class CloudBackupBundle {
  const CloudBackupBundle({
    required this.profile,
    required this.appearanceSettings,
    required this.workEntries,
    required this.leaveEntries,
    required this.scheduleOverrides,
    this.workdaySessions = const {},
    this.updatedAt,
  });

  final UserProfile profile;
  final AppAppearanceSettings appearanceSettings;
  final List<WorkEntry> workEntries;
  final List<LeaveEntry> leaveEntries;
  final List<ScheduleOverride> scheduleOverrides;
  final Map<String, WorkdaySession> workdaySessions;
  final DateTime? updatedAt;

  factory CloudBackupBundle.fromJson(Map<String, dynamic> json) {
    return CloudBackupBundle(
      profile: UserProfile.fromJson(json['profile'] as Map<String, dynamic>),
      appearanceSettings: AppAppearanceSettings.fromJson(
        json['appearanceSettings'] as Map<String, dynamic>,
      ),
      workEntries: (json['workEntries'] as List<dynamic>? ?? const [])
          .map((item) => WorkEntry.fromJson(item as Map<String, dynamic>))
          .toList(growable: false),
      leaveEntries: (json['leaveEntries'] as List<dynamic>? ?? const [])
          .map((item) => LeaveEntry.fromJson(item as Map<String, dynamic>))
          .toList(growable: false),
      scheduleOverrides:
          (json['scheduleOverrides'] as List<dynamic>? ?? const [])
              .map(
                (item) =>
                    ScheduleOverride.fromJson(item as Map<String, dynamic>),
              )
              .toList(growable: false),
      workdaySessions: _parseWorkdaySessions(json['workdaySessions']),
      updatedAt: (() {
        final rawValue = json['updatedAt'];
        if (rawValue is! String || rawValue.trim().isEmpty) {
          return null;
        }
        try {
          return DateTime.parse(rawValue).toLocal();
        } catch (_) {
          return null;
        }
      })(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'profile': profile.toJson(),
      'appearanceSettings': appearanceSettings.toJson(),
      'workEntries': workEntries.map((entry) => entry.toJson()).toList(),
      'leaveEntries': leaveEntries.map((entry) => entry.toJson()).toList(),
      'scheduleOverrides': scheduleOverrides
          .map((entry) => entry.toJson())
          .toList(),
      'workdaySessions': _workdaySessionsToJson(workdaySessions),
    };
  }

  LocalDashboardDataBundle toLocalBundle() {
    return LocalDashboardDataBundle(
      profile: profile,
      workEntries: workEntries,
      leaveEntries: leaveEntries,
      scheduleOverrides: scheduleOverrides,
      workdaySessions: workdaySessions,
    );
  }

  static CloudBackupBundle fromLocal({
    required LocalDashboardDataBundle localBundle,
    required AppAppearanceSettings appearanceSettings,
  }) {
    return CloudBackupBundle(
      profile: localBundle.profile,
      appearanceSettings: appearanceSettings,
      workEntries: localBundle.workEntries,
      leaveEntries: localBundle.leaveEntries,
      scheduleOverrides: localBundle.scheduleOverrides,
      workdaySessions: localBundle.workdaySessions,
    );
  }
}
