import 'package:work_hours_mobile/application/services/theme_preference_store.dart';
import 'package:work_hours_mobile/domain/models/leave_entry.dart';
import 'package:work_hours_mobile/domain/models/profile.dart';
import 'package:work_hours_mobile/domain/models/schedule_override.dart';
import 'package:work_hours_mobile/domain/models/work_entry.dart';

class LocalDashboardDataBundle {
  const LocalDashboardDataBundle({
    required this.profile,
    required this.workEntries,
    required this.leaveEntries,
    required this.scheduleOverrides,
  });

  final UserProfile profile;
  final List<WorkEntry> workEntries;
  final List<LeaveEntry> leaveEntries;
  final List<ScheduleOverride> scheduleOverrides;

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
    };
  }
}

class CloudBackupBundle {
  const CloudBackupBundle({
    required this.profile,
    required this.appearanceSettings,
    required this.workEntries,
    required this.leaveEntries,
    required this.scheduleOverrides,
  });

  final UserProfile profile;
  final AppAppearanceSettings appearanceSettings;
  final List<WorkEntry> workEntries;
  final List<LeaveEntry> leaveEntries;
  final List<ScheduleOverride> scheduleOverrides;

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
    };
  }

  LocalDashboardDataBundle toLocalBundle() {
    return LocalDashboardDataBundle(
      profile: profile,
      workEntries: workEntries,
      leaveEntries: leaveEntries,
      scheduleOverrides: scheduleOverrides,
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
    );
  }
}
