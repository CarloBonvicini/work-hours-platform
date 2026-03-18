import 'package:flutter_test/flutter_test.dart';
import 'package:work_hours_mobile/application/services/dashboard_service.dart';
import 'package:work_hours_mobile/data/repositories/in_memory_dashboard_repository.dart';
import 'package:work_hours_mobile/presentation/app/work_hours_app.dart';

void main() {
  testWidgets('shows bootstrap dashboard', (tester) async {
    await tester.pumpWidget(
      WorkHoursApp(
        dashboardService: DashboardService(
          repository: InMemoryDashboardRepository(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Work Hours Platform'), findsOneWidget);
    expect(find.textContaining('GitHub Releases'), findsWidgets);
    expect(find.text('Focus immediato'), findsOneWidget);
  });
}
