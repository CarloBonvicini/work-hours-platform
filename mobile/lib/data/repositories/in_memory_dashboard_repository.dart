import 'package:work_hours_mobile/domain/models/dashboard_snapshot.dart';
import 'package:work_hours_mobile/domain/repositories/dashboard_repository.dart';

class InMemoryDashboardRepository implements DashboardRepository {
  @override
  Future<DashboardSnapshot> loadSnapshot() async {
    return DashboardSnapshot(
      fullName: 'Carlo',
      monthlyTargetHours: 168,
      trackedHours: 42,
      leaveHours: 4,
      balanceHours: -122,
      focusItems: const [
        'chiudere il bootstrap Flutter',
        'agganciare il backend profilo/ore',
        'pubblicare il primo APK su GitHub Releases',
      ],
      distributionChannel: 'GitHub Releases',
    );
  }
}
