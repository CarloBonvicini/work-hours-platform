import 'package:work_hours_mobile/domain/models/dashboard_snapshot.dart';
import 'package:work_hours_mobile/domain/repositories/dashboard_repository.dart';

class DashboardService {
  DashboardService({required DashboardRepository repository})
    : _repository = repository;

  final DashboardRepository _repository;

  Future<DashboardSnapshot> loadSnapshot() {
    return _repository.loadSnapshot();
  }
}
