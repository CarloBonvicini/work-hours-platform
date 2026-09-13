// Avvio dell'app nei widget test e gesti ricorrenti di navigazione.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_hours_mobile/application/services/app_update_service.dart';
import 'package:work_hours_mobile/application/services/dashboard_service.dart';
import 'package:work_hours_mobile/application/services/onboarding_preference_store.dart';
import 'package:work_hours_mobile/application/services/support_ticket_store.dart';
import 'package:work_hours_mobile/application/services/theme_preference_store.dart';
import 'package:work_hours_mobile/application/services/update_reminder_store.dart';
import 'package:work_hours_mobile/application/services/workday_start_store.dart';
import 'package:work_hours_mobile/domain/repositories/dashboard_repository.dart';
import 'package:work_hours_mobile/presentation/app/work_hours_app.dart';

import 'fake_app_services.dart';
import 'fake_dashboard_repository.dart';

export 'fake_app_services.dart';
export 'fake_dashboard_repository.dart';

/// Monta l'app con i doppi di test e attende che si stabilizzi.
///
/// Ogni dipendenza ha un default utilizzabile: i test passano solo quella che
/// il caso in esame deve davvero controllare.
Future<void> pumpWorkHoursApp(
  WidgetTester tester, {
  DashboardRepository? repository,
  AppUpdateService? appUpdateService,
  UpdateReminderStore? updateReminderStore,
  ThemePreferenceStore? themePreferenceStore,
  WorkdayStartStore? workdayStartStore,
  SupportTicketStore? supportTicketStore,
  OnboardingPreferenceStore? onboardingPreferenceStore,
  AppAppearanceSettings? initialAppearanceSettings,
  bool hasCompletedInitialSetup = true,
}) async {
  await tester.pumpWidget(
    WorkHoursApp(
      dashboardService: DashboardService(
        repository: repository ?? FakeDashboardRepository(),
      ),
      appUpdateService: appUpdateService ?? FakeAppUpdateService(),
      updateReminderStore: updateReminderStore ?? FakeUpdateReminderStore(),
      onboardingPreferenceStore:
          onboardingPreferenceStore ??
          FakeOnboardingPreferenceStore(hasCompleted: true),
      themePreferenceStore: themePreferenceStore ?? FakeThemePreferenceStore(),
      workdayStartStore: workdayStartStore ?? FakeWorkdayStartStore(),
      supportTicketStore: supportTicketStore ?? FakeSupportTicketStore(),
      initialAppearanceSettings:
          initialAppearanceSettings ?? AppAppearanceSettings.defaults,
      hasCompletedInitialSetup: hasCompletedInitialSetup,
    ),
  );
  await tester.pumpAndSettle();
}

/// Chiude il dialogo di aggiornamento se e' comparso all'avvio.
Future<void> dismissUpdateDialogIfAny(WidgetTester tester) async {
  if (find.text('Ricordamelo piu tardi').evaluate().isEmpty) {
    return;
  }

  await tester.tap(find.text('Ricordamelo piu tardi'));
  await tester.pumpAndSettle();
}

/// Apre una sezione dal menu di navigazione (`navigation-option-<nome>`).
Future<void> openHomeSection(WidgetTester tester, String section) async {
  await tester.tap(find.byKey(const ValueKey('navigation-menu-button')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(ValueKey('navigation-option-$section')));
  await tester.pumpAndSettle();
}

/// Apre la modifica rapida della vista giorno, che di default arriva chiusa.
///
/// Idempotente: chiamarla due volte non la richiude.
Future<void> openQuickDayEditor(WidgetTester tester) async {
  final fieldFinder = find.byKey(
    const ValueKey('calendar-override-start-time-button'),
  );
  if (fieldFinder.evaluate().isNotEmpty) {
    return;
  }

  final toggleFinder = find.byKey(
    const ValueKey('calendar-quick-editor-toggle-button'),
  );
  await tester.ensureVisible(toggleFinder);
  await tester.pumpAndSettle();
  await tester.tap(toggleFinder);
  await tester.pumpAndSettle();
}

/// Data di oggi nel formato ISO usato dalle registrazioni.
String todayIsoDate() {
  final today = DateTime.now();
  return '${today.year.toString().padLeft(4, '0')}-'
      '${today.month.toString().padLeft(2, '0')}-'
      '${today.day.toString().padLeft(2, '0')}';
}
