// Avvio dell'app, aggiornamenti, tema, primo avvio e ticket di supporto.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_hours_mobile/domain/models/support_ticket.dart';

import 'support/app_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('checks for updates again when app resumes', (tester) async {
    final appUpdateService = CountingAppUpdateService();

    await pumpWorkHoursApp(tester, appUpdateService: appUpdateService);

    await tester.pumpAndSettle();
    expect(appUpdateService.checkCount, 1);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(appUpdateService.checkCount, 2);
  });

  testWidgets('snoozes update dialog when user chooses later', (tester) async {
    final reminderStore = FakeUpdateReminderStore();

    await pumpWorkHoursApp(tester, updateReminderStore: reminderStore);

    await tester.pumpAndSettle();
    await tester.tap(find.text('Ricordamelo piu tardi'));
    await tester.pumpAndSettle();

    expect(reminderStore.remindedLaterVersions, ['0.1.1']);
    expect(find.text('Aggiornamento disponibile'), findsNothing);
  });

  testWidgets('toggles dark theme from settings', (tester) async {
    final themePreferenceStore = FakeThemePreferenceStore();

    await pumpWorkHoursApp(
      tester,
      appUpdateService: CountingAppUpdateService(),
      themePreferenceStore: themePreferenceStore,
    );

    await tester.pumpAndSettle();
    await openHomeSection(tester, 'profile');

    await tester.scrollUntilVisible(
      find.text('Scuro').last,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Scuro').last);
    await tester.pumpAndSettle();

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.dark);
    expect(themePreferenceStore.savedThemeModes, [ThemeMode.dark]);
  });

  testWidgets('shows manual update action in settings', (tester) async {
    final appUpdateService = ManualCheckAppUpdateService();

    await pumpWorkHoursApp(tester, appUpdateService: appUpdateService);

    await tester.pumpAndSettle();
    await tester.tap(find.text('Ricordamelo piu tardi'));
    await tester.pumpAndSettle();
    await openHomeSection(tester, 'profile');

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('settings-update-button')),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('settings-update-button')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('settings-update-button')));
    await tester.pumpAndSettle();

    expect(appUpdateService.checkCount, 1);
    expect(find.text('Aggiornamento pronto'), findsOneWidget);
    expect(find.text('Installa'), findsOneWidget);
  });

  testWidgets('first launch asks the three setup questions and saves them', (
    tester,
  ) async {
    final onboardingStore = FakeOnboardingPreferenceStore(hasCompleted: false);
    final repository = FakeDashboardRepository();

    await pumpWorkHoursApp(
      tester,
      repository: repository,
      appUpdateService: CountingAppUpdateService(),
      onboardingPreferenceStore: onboardingStore,
      hasCompletedInitialSetup: false,
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('initial-setup-sheet')), findsOneWidget);
    // I valori di partenza sono gia' utilizzabili: si puo' confermare subito.
    expect(find.byKey(const ValueKey('initial-setup-outcome')), findsOneWidget);

    // Lavora anche il sabato e senza pausa.
    await tester.tap(
      find.byKey(const ValueKey('work-settings-working-day-toggle-saturday')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('initial-setup-break-0')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('initial-setup-confirm-button')),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('initial-setup-sheet')), findsNothing);
    expect(onboardingStore.markCompletedCalls, 1);

    final savedSchedule = repository.savedWeekdaySchedule;
    expect(savedSchedule, isNotNull);
    expect(savedSchedule!.monday.startTime, '09:00');
    expect(savedSchedule.monday.endTime, '18:00');
    expect(savedSchedule.monday.targetMinutes, 9 * 60);
    expect(savedSchedule.saturday.targetMinutes, 9 * 60);
    expect(savedSchedule.sunday.targetMinutes, 0);
  });

  testWidgets('first launch setup can be postponed without saving', (
    tester,
  ) async {
    final onboardingStore = FakeOnboardingPreferenceStore(hasCompleted: false);
    final repository = FakeDashboardRepository();

    await pumpWorkHoursApp(
      tester,
      repository: repository,
      appUpdateService: CountingAppUpdateService(),
      onboardingPreferenceStore: onboardingStore,
      hasCompletedInitialSetup: false,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('initial-setup-skip-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('initial-setup-sheet')), findsNothing);
    // Rimandare non deve toccare il profilo, ma non si richiede al riavvio.
    expect(repository.savedWeekdaySchedule, isNull);
    expect(onboardingStore.markCompletedCalls, 1);
  });

  testWidgets('submits a support ticket from the app', (tester) async {
    final repository = FakeDashboardRepository();
    await tester.binding.setSurfaceSize(const Size(1400, 2200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await pumpWorkHoursApp(
      tester,
      repository: repository,
      appUpdateService: CountingAppUpdateService(),
    );

    await tester.pumpAndSettle();
    await openHomeSection(tester, 'ticket');

    expect(find.byKey(const ValueKey('ticket-api-hint')), findsNothing);
    expect(
      find.byKey(const ValueKey('ticket-attachments-button')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('ticket-category-feature')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('ticket-subject-field')),
      'Vista mensile migliore',
    );
    await tester.enterText(
      find.byKey(const ValueKey('ticket-message-field')),
      'Vorrei una vista del calendario piu leggibile.',
    );
    await tester.tap(find.byKey(const ValueKey('ticket-submit-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(repository.submittedTicketCategory, SupportTicketCategory.feature);
    expect(repository.submittedTicketSubject, 'Vista mensile migliore');
    expect(
      repository.submittedTicketMessage,
      'Vorrei una vista del calendario piu leggibile.',
    );
  });
}
