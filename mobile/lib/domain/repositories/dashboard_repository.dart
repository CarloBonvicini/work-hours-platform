import 'package:work_hours_mobile/domain/models/dashboard_snapshot.dart';

abstract class DashboardRepository {
  Future<DashboardSnapshot> loadSnapshot();
}
