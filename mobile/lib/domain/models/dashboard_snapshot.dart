import 'package:work_hours_mobile/domain/models/monthly_summary.dart';
import 'package:work_hours_mobile/domain/models/profile.dart';
import 'package:work_hours_mobile/domain/models/work_entry.dart';

class DashboardSnapshot {
  const DashboardSnapshot({
    required this.profile,
    required this.summary,
    required this.workEntries,
    required this.apiBaseUrl,
  });

  final UserProfile profile;
  final MonthlySummary summary;
  final List<WorkEntry> workEntries;
  final String apiBaseUrl;
}
