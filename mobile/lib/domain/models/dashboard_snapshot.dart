import 'package:work_hours_mobile/domain/models/leave_entry.dart';
import 'package:work_hours_mobile/domain/models/monthly_expected_minutes.dart';
import 'package:work_hours_mobile/domain/models/monthly_summary.dart';
import 'package:work_hours_mobile/domain/models/profile.dart';
import 'package:work_hours_mobile/domain/models/schedule_override.dart';
import 'package:work_hours_mobile/domain/models/work_entry.dart';

class DashboardSnapshot {
  const DashboardSnapshot({
    required this.profile,
    required this.summary,
    required this.workEntries,
    required this.leaveEntries,
    required this.scheduleOverrides,
    required this.apiBaseUrl,
    this.trackingStartDate,
  });

  final UserProfile profile;
  final MonthlySummary summary;
  final List<WorkEntry> workEntries;
  final List<LeaveEntry> leaveEntries;
  final List<ScheduleOverride> scheduleOverrides;
  final String apiBaseUrl;

  /// Giorno della prima registrazione: da li' i giorni passati pesano sul
  /// saldo. Null se non si sa, e allora pesano tutti.
  final String? trackingStartDate;

  /// Se il giorno [isoDate] pesa sul saldo: vedi [dayCountsInBalance].
  bool countsInBalance(
    String isoDate, {
    required bool hasRegistrations,
    DateTime? now,
  }) {
    return dayCountsInBalance(
      isoDate: isoDate,
      todayIsoDate: formatIsoDate(now ?? DateTime.now()),
      trackingStartDate: trackingStartDate,
      hasRegistrations: hasRegistrations,
    );
  }

  factory DashboardSnapshot.fromJson(Map<String, dynamic> json) {
    return DashboardSnapshot(
      profile: UserProfile.fromJson(json['profile'] as Map<String, dynamic>),
      summary: MonthlySummary.fromJson(json['summary'] as Map<String, dynamic>),
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
      apiBaseUrl: json['apiBaseUrl'] as String? ?? '',
      trackingStartDate: json['trackingStartDate'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'profile': profile.toJson(),
      'summary': summary.toJson(),
      'workEntries': workEntries.map((entry) => entry.toJson()).toList(),
      'leaveEntries': leaveEntries.map((entry) => entry.toJson()).toList(),
      'scheduleOverrides': scheduleOverrides
          .map((override) => override.toJson())
          .toList(),
      'apiBaseUrl': apiBaseUrl,
      'trackingStartDate': trackingStartDate,
    };
  }
}
