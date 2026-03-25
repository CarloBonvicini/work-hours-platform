import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_hours_mobile/application/services/app_update_service.dart';
import 'package:work_hours_mobile/application/services/dashboard_service.dart';
import 'package:work_hours_mobile/application/services/onboarding_preference_store.dart';
import 'package:work_hours_mobile/application/services/support_ticket_store.dart';
import 'package:work_hours_mobile/application/services/theme_preference_store.dart';
import 'package:work_hours_mobile/application/services/update_launcher.dart';
import 'package:work_hours_mobile/application/services/update_reminder_store.dart';
import 'package:work_hours_mobile/application/services/workday_start_store.dart';
import 'package:work_hours_mobile/domain/models/app_update.dart';
import 'package:work_hours_mobile/domain/models/dashboard_snapshot.dart';
import 'package:work_hours_mobile/domain/models/day_schedule.dart';
import 'package:work_hours_mobile/domain/models/leave_entry.dart';
import 'package:work_hours_mobile/domain/models/monthly_summary.dart';
import 'package:work_hours_mobile/domain/models/profile.dart';
import 'package:work_hours_mobile/domain/models/schedule_override.dart';
import 'package:work_hours_mobile/domain/models/support_ticket.dart';
import 'package:work_hours_mobile/domain/models/user_work_rules.dart';
import 'package:work_hours_mobile/domain/models/weekday_schedule.dart';
import 'package:work_hours_mobile/domain/models/weekday_target_minutes.dart';
import 'package:work_hours_mobile/domain/models/work_entry.dart';
import 'package:work_hours_mobile/domain/repositories/dashboard_repository.dart';
import 'package:work_hours_mobile/presentation/app/work_hours_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('shows simplified dashboard flow', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 2200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      WorkHoursApp(
        dashboardService: DashboardService(
          repository: _FakeDashboardRepository(),
        ),
        appUpdateService: _FakeAppUpdateService(),
        updateReminderStore: _FakeUpdateReminderStore(),
        onboardingPreferenceStore: _FakeOnboardingPreferenceStore(
          hasCompleted: true,
        ),
        themePreferenceStore: _FakeThemePreferenceStore(),
        workdayStartStore: _FakeWorkdayStartStore(),
        supportTicketStore: _FakeSupportTicketStore(),
        hasCompletedInitialSetup: true,
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Ciao Carlo Bonvicini'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('navigation-menu-button')),
      findsOneWidget,
    );
    expect(find.text('Navigazione'), findsNothing);
    expect(find.text('Settimana'), findsWidgets);
    expect(find.text('Impostazioni'), findsNothing);
    expect(find.text('Panoramica del mese'), findsNothing);
    expect(find.byKey(const ValueKey('home-section-overview')), findsNothing);
    expect(find.byKey(const ValueKey('home-section-quickEntry')), findsNothing);
    expect(
      find.byKey(const ValueKey('home-section-recentActivity')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('home-section-profile')), findsNothing);
    expect(find.byKey(const ValueKey('home-section-ticket')), findsNothing);
    expect(find.text('Aggiornamento disponibile'), findsOneWidget);
    expect(find.text('Ricordamelo piu tardi'), findsOneWidget);
    expect(find.text('Aggiorna'), findsNothing);

    await tester.tap(find.text('Ricordamelo piu tardi'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('navigation-menu-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('navigation-option-day')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('navigation-option-calendar')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('navigation-option-workSettings')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('navigation-option-profile')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('navigation-option-ticket')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('navigation-option-day')));
    await tester.pumpAndSettle();

    expect(find.text('Oggi'), findsWidgets);
    expect(
      find.byKey(const ValueKey('calendar-record-start-button')),
      findsOneWidget,
    );
    expect(find.text('Orario standard'), findsOneWidget);
    expect(find.text('Inizia da qui'), findsOneWidget);
    expect(
      tester
          .widget<Text>(
            find.byKey(const ValueKey('calendar-live-day-balance-value')),
          )
          .data,
      'Da iniziare',
    );
    expect(
      tester
          .widget<Text>(
            find.byKey(const ValueKey('calendar-live-suggested-exit-value')),
          )
          .data,
      'Da calcolare',
    );
    await tester.tap(
      find.byKey(const ValueKey('calendar-record-start-button')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('calendar-start-break-button')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('calendar-end-workday-button')),
      findsOneWidget,
    );

    expect(
      find.byKey(const ValueKey('calendar-override-start-time-button')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('calendar-override-target-value')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('calendar-override-end-time-button')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('calendar-override-break-value')),
      findsOneWidget,
    );
    expect(find.text('Lavorate'), findsOneWidget);
    expect(find.text('Ore attese'), findsOneWidget);
    expect(find.text('Saldo mese'), findsOneWidget);
    expect(find.text('Esci alle'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('calendar-live-worked-value')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('calendar-live-expected-value')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('calendar-live-day-balance-value')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('calendar-live-month-balance-value')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('calendar-live-suggested-exit-value')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('calendar-day-agenda-toggle-button')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('calendar-record-start-button')),
      findsNothing,
    );
    expect(find.text('Ore previste per questo giorno'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('navigation-menu-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('navigation-option-calendar')));
    await tester.pumpAndSettle();

    expect(find.text('Calendario'), findsWidgets);
    expect(find.text('Settimana'), findsWidgets);
    expect(find.text('Mese'), findsWidgets);
    expect(find.text('Anno'), findsWidgets);
    expect(
      find.byKey(const ValueKey('calendar-record-start-button')),
      findsNothing,
    );
  });

  testWidgets(
    'does not treat standard hours as worked when only the target is set',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      Future<void> openDaySection() async {
        await tester.tap(find.byKey(const ValueKey('navigation-menu-button')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('navigation-option-day')));
        await tester.pumpAndSettle();
      }

      final today = DateTime.now();
      final todayIsoDate =
          '${today.year.toString().padLeft(4, '0')}-'
          '${today.month.toString().padLeft(2, '0')}-'
          '${today.day.toString().padLeft(2, '0')}';

      await tester.pumpWidget(
        WorkHoursApp(
          dashboardService: DashboardService(
            repository: _FakeDashboardRepository(
              initialScheduleOverrides: {
                todayIsoDate: ScheduleOverride(
                  id: 'override-target-only',
                  date: todayIsoDate,
                  targetMinutes: 475,
                ),
              },
            ),
          ),
          appUpdateService: _FakeAppUpdateService(),
          updateReminderStore: _FakeUpdateReminderStore(),
          onboardingPreferenceStore: _FakeOnboardingPreferenceStore(
            hasCompleted: true,
          ),
          themePreferenceStore: _FakeThemePreferenceStore(),
          workdayStartStore: _FakeWorkdayStartStore(),
          supportTicketStore: _FakeSupportTicketStore(),
          hasCompletedInitialSetup: true,
        ),
      );

      await tester.pumpAndSettle();
      if (find.text('Ricordamelo piu tardi').evaluate().isNotEmpty) {
        await tester.tap(find.text('Ricordamelo piu tardi'));
        await tester.pumpAndSettle();
      }
      await openDaySection();

      expect(
        tester
            .widget<Text>(
              find.byKey(const ValueKey('calendar-live-worked-value')),
            )
            .data,
        '0:00',
      );
      expect(
        tester
            .widget<Text>(
              find.byKey(const ValueKey('calendar-live-day-balance-value')),
            )
            .data,
        'Da iniziare',
      );
      expect(
        tester
            .widget<Text>(
              find.byKey(const ValueKey('calendar-live-suggested-exit-value')),
            )
            .data,
        'Da calcolare',
      );
    },
  );

  testWidgets('uses a compact week layout on narrow screens', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      WorkHoursApp(
        dashboardService: DashboardService(
          repository: _FakeDashboardRepository(),
        ),
        appUpdateService: _FakeAppUpdateService(),
        updateReminderStore: _FakeUpdateReminderStore(),
        onboardingPreferenceStore: _FakeOnboardingPreferenceStore(
          hasCompleted: true,
        ),
        themePreferenceStore: _FakeThemePreferenceStore(),
        workdayStartStore: _FakeWorkdayStartStore(),
        supportTicketStore: _FakeSupportTicketStore(),
        hasCompletedInitialSetup: true,
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('Ricordamelo piu tardi'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('navigation-menu-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('navigation-option-calendar')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settimana').last);
    await tester.pumpAndSettle();

    expect(find.text('Tocca un giorno per vederlo in grande.'), findsNothing);
    expect(find.text('Giorno selezionato'), findsNothing);
    expect(
      find.byKey(const ValueKey('calendar-week-row-2026-03-23')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('calendar-week-row-2026-03-29')),
      findsOneWidget,
    );
    expect(find.text('Ore 6:00'), findsWidgets);
    expect(find.text('Debito: 6:00'), findsWidgets);
    expect(find.text('In pari'), findsNothing);
    expect(find.text('Pausa 0:30'), findsNothing);
    expect(find.text('08:30 - 15:00'), findsNothing);
  });

  testWidgets('organizes work settings into clear sections', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      WorkHoursApp(
        dashboardService: DashboardService(
          repository: _FakeDashboardRepository(),
        ),
        appUpdateService: _FakeAppUpdateService(),
        updateReminderStore: _FakeUpdateReminderStore(),
        onboardingPreferenceStore: _FakeOnboardingPreferenceStore(
          hasCompleted: true,
        ),
        themePreferenceStore: _FakeThemePreferenceStore(),
        workdayStartStore: _FakeWorkdayStartStore(),
        supportTicketStore: _FakeSupportTicketStore(),
        hasCompletedInitialSetup: true,
      ),
    );

    await tester.pumpAndSettle();
    if (find.text('Ricordamelo piu tardi').evaluate().isNotEmpty) {
      await tester.tap(find.text('Ricordamelo piu tardi'));
      await tester.pumpAndSettle();
    }

    await tester.tap(find.byKey(const ValueKey('navigation-menu-button')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('navigation-option-workSettings')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Orario di lavoro'), findsOneWidget);
    expect(find.text('Quanto devi lavorare'), findsOneWidget);
    expect(find.text('Limiti'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('work-settings-schedule-toggle-button')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('work-settings-rules-toggle-button')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('work-settings-limits-toggle-button')),
      findsOneWidget,
    );
    expect(
      find.text(
        'Scegli il massimo credito o debito che l app puo conteggiare nel giorno e nel mese. Se non vuoi limiti, lascia Nessun limite.',
      ),
      findsOneWidget,
    );
    expect(find.text('Stesso orario lun-ven'), findsOneWidget);
    expect(find.text('Disattiva per personalizzare i giorni.'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('work-settings-lunch-break-monday')),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is RichText &&
            widget.text.toPlainText().contains('Ore attese'),
      ),
      findsWidgets,
    );
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is RichText &&
            widget.text.toPlainText().contains('Pausa minima'),
      ),
      findsWidgets,
    );
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is RichText &&
            widget.text.toPlainText().contains('Nessun limite'),
      ),
      findsWidgets,
    );
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is RichText &&
            widget.text.toPlainText().contains('Max credito giorno'),
      ),
      findsWidgets,
    );
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is RichText &&
            widget.text.toPlainText().contains('Max debito mese'),
      ),
      findsWidgets,
    );
    expect(find.text('Ripristina valori'), findsOneWidget);
    expect(find.text('Salva'), findsOneWidget);
    expect(find.text('Ore giornaliere attese'), findsNothing);
    expect(find.text('Carica orari'), findsNothing);
    expect(find.text('Salva orari'), findsNothing);
  });

  testWidgets('toggles weekday lunch break in work settings', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      WorkHoursApp(
        dashboardService: DashboardService(
          repository: _FakeDashboardRepository(),
        ),
        appUpdateService: _FakeAppUpdateService(),
        updateReminderStore: _FakeUpdateReminderStore(),
        onboardingPreferenceStore: _FakeOnboardingPreferenceStore(
          hasCompleted: true,
        ),
        themePreferenceStore: _FakeThemePreferenceStore(),
        workdayStartStore: _FakeWorkdayStartStore(),
        supportTicketStore: _FakeSupportTicketStore(),
        hasCompletedInitialSetup: true,
      ),
    );

    await tester.pumpAndSettle();
    if (find.text('Ricordamelo piu tardi').evaluate().isNotEmpty) {
      await tester.tap(find.text('Ricordamelo piu tardi'));
      await tester.pumpAndSettle();
    }

    await tester.tap(find.byKey(const ValueKey('navigation-menu-button')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('navigation-option-workSettings')),
    );
    await tester.pumpAndSettle();

    final mondayLunchBreakFinder = find.byKey(
      const ValueKey('work-settings-lunch-break-monday'),
    );
    expect(mondayLunchBreakFinder, findsOneWidget);
    expect(tester.widget<Checkbox>(mondayLunchBreakFinder).value, isTrue);

    await tester.tap(mondayLunchBreakFinder);
    await tester.pumpAndSettle();

    expect(tester.widget<Checkbox>(mondayLunchBreakFinder).value, isFalse);
  });

  testWidgets('persists collapsed state for work settings sections', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 2200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final themePreferenceStore = _FakeThemePreferenceStore();

    Future<void> openWorkSettings() async {
      final menuButtonFinder = find.byKey(
        const ValueKey('navigation-menu-button'),
      );
      if (menuButtonFinder.evaluate().isNotEmpty) {
        await tester.tap(menuButtonFinder);
        await tester.pumpAndSettle();
      }
      await tester.tap(
        find.byKey(const ValueKey('navigation-option-workSettings')),
      );
      await tester.pumpAndSettle();
    }

    await tester.pumpWidget(
      WorkHoursApp(
        dashboardService: DashboardService(
          repository: _FakeDashboardRepository(),
        ),
        appUpdateService: _FakeAppUpdateService(),
        updateReminderStore: _FakeUpdateReminderStore(),
        onboardingPreferenceStore: _FakeOnboardingPreferenceStore(
          hasCompleted: true,
        ),
        themePreferenceStore: themePreferenceStore,
        workdayStartStore: _FakeWorkdayStartStore(),
        supportTicketStore: _FakeSupportTicketStore(),
        hasCompletedInitialSetup: true,
      ),
    );

    await tester.pumpAndSettle();
    if (find.text('Ricordamelo piu tardi').evaluate().isNotEmpty) {
      await tester.tap(find.text('Ricordamelo piu tardi'));
      await tester.pumpAndSettle();
    }
    await openWorkSettings();

    expect(themePreferenceStore.settings.expandWorkSettingsLimits, isTrue);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('work-settings-limits-toggle-button')),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(
      find.byKey(const ValueKey('work-settings-limits-toggle-button')),
    );
    await tester.pumpAndSettle();

    expect(themePreferenceStore.settings.expandWorkSettingsLimits, isFalse);
    expect(
      find.text(
        'Scegli il massimo credito o debito che l app puo conteggiare nel giorno e nel mese. Se non vuoi limiti, lascia Nessun limite.',
      ),
      findsNothing,
    );
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is RichText &&
            widget.text.toPlainText().contains('Max credito giorno'),
      ),
      findsNothing,
    );

    await tester.pumpWidget(
      WorkHoursApp(
        dashboardService: DashboardService(
          repository: _FakeDashboardRepository(),
        ),
        appUpdateService: _FakeAppUpdateService(),
        updateReminderStore: _FakeUpdateReminderStore(),
        onboardingPreferenceStore: _FakeOnboardingPreferenceStore(
          hasCompleted: true,
        ),
        themePreferenceStore: themePreferenceStore,
        workdayStartStore: _FakeWorkdayStartStore(),
        supportTicketStore: _FakeSupportTicketStore(),
        initialAppearanceSettings: themePreferenceStore.settings,
        hasCompletedInitialSetup: true,
      ),
    );

    await tester.pumpAndSettle();
    if (find.text('Ricordamelo piu tardi').evaluate().isNotEmpty) {
      await tester.tap(find.text('Ricordamelo piu tardi'));
      await tester.pumpAndSettle();
    }
    await openWorkSettings();

    expect(themePreferenceStore.settings.expandWorkSettingsLimits, isFalse);
    expect(
      find.byKey(const ValueKey('work-settings-limits-toggle-button')),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is RichText &&
            widget.text.toPlainText().contains('Max credito giorno'),
      ),
      findsNothing,
    );
  });

  testWidgets('supports undo and redo in quick day editing', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      WorkHoursApp(
        dashboardService: DashboardService(
          repository: _FakeDashboardRepository(),
        ),
        appUpdateService: _FakeAppUpdateService(),
        updateReminderStore: _FakeUpdateReminderStore(),
        onboardingPreferenceStore: _FakeOnboardingPreferenceStore(
          hasCompleted: true,
        ),
        themePreferenceStore: _FakeThemePreferenceStore(),
        workdayStartStore: _FakeWorkdayStartStore(),
        supportTicketStore: _FakeSupportTicketStore(),
        hasCompletedInitialSetup: true,
      ),
    );

    await tester.pumpAndSettle();
    if (find.text('Ricordamelo piu tardi').evaluate().isNotEmpty) {
      await tester.tap(find.text('Ricordamelo piu tardi'));
      await tester.pumpAndSettle();
    }

    await tester.tap(find.byKey(const ValueKey('navigation-menu-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('navigation-option-day')));
    await tester.pumpAndSettle();

    final exitPosition = tester.getTopLeft(
      find.byKey(const ValueKey('calendar-override-end-time-button')),
    );
    final targetPosition = tester.getTopLeft(
      find.byKey(const ValueKey('calendar-override-target-value')),
    );
    expect(exitPosition.dy, targetPosition.dy);
    expect(exitPosition.dx, lessThan(targetPosition.dx));

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('calendar-override-target-value')),
        matching: find.text('6:00'),
      ),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('calendar-override-day-off-button')),
    );
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('calendar-override-target-value')),
        matching: find.text('0:00'),
      ),
      findsOneWidget,
    );
    expect(
      tester
          .widget<Text>(
            find.byKey(const ValueKey('calendar-live-suggested-exit-value')),
          )
          .data,
      'Libero',
    );
    expect(
      tester
          .widget<Text>(
            find.byKey(const ValueKey('calendar-live-day-balance-value')),
          )
          .data,
      '0:00',
    );

    await tester.tap(
      find.byKey(const ValueKey('calendar-override-undo-button')),
    );
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('calendar-override-target-value')),
        matching: find.text('6:00'),
      ),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('calendar-override-redo-button')),
    );
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('calendar-override-target-value')),
        matching: find.text('0:00'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('shows worked hours in the quick day time picker', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      WorkHoursApp(
        dashboardService: DashboardService(
          repository: _FakeDashboardRepository(),
        ),
        appUpdateService: _FakeAppUpdateService(),
        updateReminderStore: _FakeUpdateReminderStore(),
        onboardingPreferenceStore: _FakeOnboardingPreferenceStore(
          hasCompleted: true,
        ),
        themePreferenceStore: _FakeThemePreferenceStore(),
        workdayStartStore: _FakeWorkdayStartStore(),
        supportTicketStore: _FakeSupportTicketStore(),
        hasCompletedInitialSetup: true,
      ),
    );

    await tester.pumpAndSettle();
    if (find.text('Ricordamelo piu tardi').evaluate().isNotEmpty) {
      await tester.tap(find.text('Ricordamelo piu tardi'));
      await tester.pumpAndSettle();
    }

    await tester.tap(find.byKey(const ValueKey('navigation-menu-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('navigation-option-day')));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('calendar-override-end-time-button')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Uscita'), findsWidgets);
    expect(
      find.byKey(const ValueKey('schedule-time-wheel-helper-text')),
      findsOneWidget,
    );
    final helperText = tester
        .widget<Text>(
          find.byKey(const ValueKey('schedule-time-wheel-helper-text')),
        )
        .data;
    expect(helperText, startsWith('Ore di lavoro: '));
  });

  testWidgets('persists collapsed state for quick day editor', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final themePreferenceStore = _FakeThemePreferenceStore();

    Future<void> openDaySection() async {
      await tester.tap(find.byKey(const ValueKey('navigation-menu-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('navigation-option-day')));
      await tester.pumpAndSettle();
    }

    await tester.pumpWidget(
      WorkHoursApp(
        dashboardService: DashboardService(
          repository: _FakeDashboardRepository(),
        ),
        appUpdateService: _FakeAppUpdateService(),
        updateReminderStore: _FakeUpdateReminderStore(),
        onboardingPreferenceStore: _FakeOnboardingPreferenceStore(
          hasCompleted: true,
        ),
        themePreferenceStore: themePreferenceStore,
        workdayStartStore: _FakeWorkdayStartStore(),
        supportTicketStore: _FakeSupportTicketStore(),
        hasCompletedInitialSetup: true,
      ),
    );

    await tester.pumpAndSettle();
    if (find.text('Ricordamelo piu tardi').evaluate().isNotEmpty) {
      await tester.tap(find.text('Ricordamelo piu tardi'));
      await tester.pumpAndSettle();
    }
    await openDaySection();

    expect(
      find.byKey(const ValueKey('calendar-override-start-time-button')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('calendar-quick-editor-toggle-button')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('calendar-override-start-time-button')),
      findsNothing,
    );
    expect(themePreferenceStore.settings.expandDayQuickEditor, isFalse);

    await tester.pumpWidget(
      WorkHoursApp(
        dashboardService: DashboardService(
          repository: _FakeDashboardRepository(),
        ),
        appUpdateService: _FakeAppUpdateService(),
        updateReminderStore: _FakeUpdateReminderStore(),
        onboardingPreferenceStore: _FakeOnboardingPreferenceStore(
          hasCompleted: true,
        ),
        themePreferenceStore: themePreferenceStore,
        workdayStartStore: _FakeWorkdayStartStore(),
        supportTicketStore: _FakeSupportTicketStore(),
        initialAppearanceSettings: themePreferenceStore.settings,
        hasCompletedInitialSetup: true,
      ),
    );

    await tester.pumpAndSettle();
    if (find.text('Ricordamelo piu tardi').evaluate().isNotEmpty) {
      await tester.tap(find.text('Ricordamelo piu tardi'));
      await tester.pumpAndSettle();
    }
    await openDaySection();

    expect(
      find.byKey(const ValueKey('calendar-quick-editor-toggle-button')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('calendar-override-start-time-button')),
      findsNothing,
    );
  });

  testWidgets('persists collapsed state for the today workday card', (
    tester,
  ) async {
    final themePreferenceStore = _FakeThemePreferenceStore();

    Future<void> openDaySection() async {
      await tester.tap(find.byKey(const ValueKey('navigation-menu-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('navigation-option-day')));
      await tester.pumpAndSettle();
    }

    await tester.pumpWidget(
      WorkHoursApp(
        dashboardService: DashboardService(
          repository: _FakeDashboardRepository(),
        ),
        appUpdateService: _FakeAppUpdateService(),
        updateReminderStore: _FakeUpdateReminderStore(),
        onboardingPreferenceStore: _FakeOnboardingPreferenceStore(
          hasCompleted: true,
        ),
        themePreferenceStore: themePreferenceStore,
        workdayStartStore: _FakeWorkdayStartStore(),
        supportTicketStore: _FakeSupportTicketStore(),
        hasCompletedInitialSetup: true,
      ),
    );

    await tester.pumpAndSettle();
    if (find.text('Ricordamelo piu tardi').evaluate().isNotEmpty) {
      await tester.tap(find.text('Ricordamelo piu tardi'));
      await tester.pumpAndSettle();
    }
    await openDaySection();

    expect(
      find.byKey(const ValueKey('calendar-record-start-button')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('calendar-workday-card-toggle-button')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('calendar-record-start-button')),
      findsNothing,
    );
    expect(find.text('Giornata di oggi'), findsNothing);
    expect(find.text('Entrata, pausa, uscita.'), findsOneWidget);
    expect(themePreferenceStore.settings.expandDayWorkdayCard, isFalse);

    await tester.pumpWidget(
      WorkHoursApp(
        dashboardService: DashboardService(
          repository: _FakeDashboardRepository(),
        ),
        appUpdateService: _FakeAppUpdateService(),
        updateReminderStore: _FakeUpdateReminderStore(),
        onboardingPreferenceStore: _FakeOnboardingPreferenceStore(
          hasCompleted: true,
        ),
        themePreferenceStore: themePreferenceStore,
        workdayStartStore: _FakeWorkdayStartStore(),
        supportTicketStore: _FakeSupportTicketStore(),
        initialAppearanceSettings: themePreferenceStore.settings,
        hasCompletedInitialSetup: true,
      ),
    );

    await tester.pumpAndSettle();
    if (find.text('Ricordamelo piu tardi').evaluate().isNotEmpty) {
      await tester.tap(find.text('Ricordamelo piu tardi'));
      await tester.pumpAndSettle();
    }
    await openDaySection();

    expect(
      find.byKey(const ValueKey('calendar-workday-card-toggle-button')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('calendar-record-start-button')),
      findsNothing,
    );
    expect(find.text('Giornata di oggi'), findsNothing);
    expect(find.text('Entrata, pausa, uscita.'), findsOneWidget);
  });

  testWidgets('persists collapsed state for day agenda', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final themePreferenceStore = _FakeThemePreferenceStore();

    Future<void> openDaySection() async {
      await tester.tap(find.byKey(const ValueKey('navigation-menu-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('navigation-option-day')));
      await tester.pumpAndSettle();
    }

    await tester.pumpWidget(
      WorkHoursApp(
        dashboardService: DashboardService(
          repository: _FakeDashboardRepository(),
        ),
        appUpdateService: _FakeAppUpdateService(),
        updateReminderStore: _FakeUpdateReminderStore(),
        onboardingPreferenceStore: _FakeOnboardingPreferenceStore(
          hasCompleted: true,
        ),
        themePreferenceStore: themePreferenceStore,
        workdayStartStore: _FakeWorkdayStartStore(),
        supportTicketStore: _FakeSupportTicketStore(),
        hasCompletedInitialSetup: true,
      ),
    );

    await tester.pumpAndSettle();
    if (find.text('Ricordamelo piu tardi').evaluate().isNotEmpty) {
      await tester.tap(find.text('Ricordamelo piu tardi'));
      await tester.pumpAndSettle();
    }
    await openDaySection();

    expect(
      find.byKey(const ValueKey('calendar-day-agenda-toggle-button')),
      findsOneWidget,
    );
    expect(themePreferenceStore.settings.expandDayAgenda, isFalse);
    await tester.ensureVisible(
      find.byKey(const ValueKey('calendar-day-agenda-toggle-button')),
    );

    await tester.tap(
      find.byKey(const ValueKey('calendar-day-agenda-toggle-button')),
    );
    await tester.pumpAndSettle();

    expect(themePreferenceStore.settings.expandDayAgenda, isTrue);

    await tester.ensureVisible(
      find.byKey(const ValueKey('calendar-day-agenda-toggle-button')),
    );
    await tester.tap(
      find.byKey(const ValueKey('calendar-day-agenda-toggle-button')),
    );
    await tester.pumpAndSettle();

    expect(themePreferenceStore.settings.expandDayAgenda, isFalse);

    await tester.pumpWidget(
      WorkHoursApp(
        dashboardService: DashboardService(
          repository: _FakeDashboardRepository(),
        ),
        appUpdateService: _FakeAppUpdateService(),
        updateReminderStore: _FakeUpdateReminderStore(),
        onboardingPreferenceStore: _FakeOnboardingPreferenceStore(
          hasCompleted: true,
        ),
        themePreferenceStore: themePreferenceStore,
        workdayStartStore: _FakeWorkdayStartStore(),
        supportTicketStore: _FakeSupportTicketStore(),
        initialAppearanceSettings: themePreferenceStore.settings,
        hasCompletedInitialSetup: true,
      ),
    );

    await tester.pumpAndSettle();
    if (find.text('Ricordamelo piu tardi').evaluate().isNotEmpty) {
      await tester.tap(find.text('Ricordamelo piu tardi'));
      await tester.pumpAndSettle();
    }
    await openDaySection();

    expect(
      find.byKey(const ValueKey('calendar-day-agenda-toggle-button')),
      findsOneWidget,
    );
    expect(find.text('Agenda oraria'), findsOneWidget);
  });

  testWidgets('expands collapsible day sections when tapping the title', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    Future<void> openDaySection() async {
      await tester.tap(find.byKey(const ValueKey('navigation-menu-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('navigation-option-day')));
      await tester.pumpAndSettle();
    }

    await tester.pumpWidget(
      WorkHoursApp(
        dashboardService: DashboardService(
          repository: _FakeDashboardRepository(),
        ),
        appUpdateService: _FakeAppUpdateService(),
        updateReminderStore: _FakeUpdateReminderStore(),
        onboardingPreferenceStore: _FakeOnboardingPreferenceStore(
          hasCompleted: true,
        ),
        themePreferenceStore: _FakeThemePreferenceStore(),
        workdayStartStore: _FakeWorkdayStartStore(),
        supportTicketStore: _FakeSupportTicketStore(),
        hasCompletedInitialSetup: true,
      ),
    );

    await tester.pumpAndSettle();
    if (find.text('Ricordamelo piu tardi').evaluate().isNotEmpty) {
      await tester.tap(find.text('Ricordamelo piu tardi'));
      await tester.pumpAndSettle();
    }
    await openDaySection();

    await tester.tap(
      find.byKey(const ValueKey('calendar-workday-card-toggle-button')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('calendar-quick-editor-toggle-button')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('calendar-record-start-button')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('calendar-override-start-time-button')),
      findsNothing,
    );

    await tester.tap(find.text('Entrata, pausa, uscita.'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('calendar-record-start-button')),
      findsOneWidget,
    );

    await tester.tap(find.text('Modifica rapida'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('calendar-override-start-time-button')),
      findsOneWidget,
    );

    await tester.tap(find.text('Agenda oraria'));
    await tester.pumpAndSettle();
    expect(find.text('06:00'), findsWidgets);
  });

  testWidgets('checks for updates again when app resumes', (tester) async {
    final appUpdateService = _CountingAppUpdateService();

    await tester.pumpWidget(
      WorkHoursApp(
        dashboardService: DashboardService(
          repository: _FakeDashboardRepository(),
        ),
        appUpdateService: appUpdateService,
        updateReminderStore: _FakeUpdateReminderStore(),
        onboardingPreferenceStore: _FakeOnboardingPreferenceStore(
          hasCompleted: true,
        ),
        themePreferenceStore: _FakeThemePreferenceStore(),
        workdayStartStore: _FakeWorkdayStartStore(),
        supportTicketStore: _FakeSupportTicketStore(),
        hasCompletedInitialSetup: true,
      ),
    );

    await tester.pumpAndSettle();
    expect(appUpdateService.checkCount, 1);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(appUpdateService.checkCount, 2);
  });

  testWidgets('snoozes update dialog when user chooses later', (tester) async {
    final reminderStore = _FakeUpdateReminderStore();

    await tester.pumpWidget(
      WorkHoursApp(
        dashboardService: DashboardService(
          repository: _FakeDashboardRepository(),
        ),
        appUpdateService: _FakeAppUpdateService(),
        updateReminderStore: reminderStore,
        onboardingPreferenceStore: _FakeOnboardingPreferenceStore(
          hasCompleted: true,
        ),
        themePreferenceStore: _FakeThemePreferenceStore(),
        workdayStartStore: _FakeWorkdayStartStore(),
        supportTicketStore: _FakeSupportTicketStore(),
        hasCompletedInitialSetup: true,
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('Ricordamelo piu tardi'));
    await tester.pumpAndSettle();

    expect(reminderStore.remindedLaterVersions, ['0.1.1']);
    expect(find.text('Aggiornamento disponibile'), findsNothing);
  });

  testWidgets('toggles dark theme from settings', (tester) async {
    final themePreferenceStore = _FakeThemePreferenceStore();

    await tester.pumpWidget(
      WorkHoursApp(
        dashboardService: DashboardService(
          repository: _FakeDashboardRepository(),
        ),
        appUpdateService: _CountingAppUpdateService(),
        updateReminderStore: _FakeUpdateReminderStore(),
        onboardingPreferenceStore: _FakeOnboardingPreferenceStore(
          hasCompleted: true,
        ),
        themePreferenceStore: themePreferenceStore,
        workdayStartStore: _FakeWorkdayStartStore(),
        supportTicketStore: _FakeSupportTicketStore(),
        hasCompletedInitialSetup: true,
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('navigation-menu-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('navigation-option-profile')));
    await tester.pumpAndSettle();

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
    final appUpdateService = _ManualCheckAppUpdateService();

    await tester.pumpWidget(
      WorkHoursApp(
        dashboardService: DashboardService(
          repository: _FakeDashboardRepository(),
        ),
        appUpdateService: appUpdateService,
        updateReminderStore: _FakeUpdateReminderStore(),
        onboardingPreferenceStore: _FakeOnboardingPreferenceStore(
          hasCompleted: true,
        ),
        themePreferenceStore: _FakeThemePreferenceStore(),
        workdayStartStore: _FakeWorkdayStartStore(),
        supportTicketStore: _FakeSupportTicketStore(),
        hasCompletedInitialSetup: true,
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('Ricordamelo piu tardi'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('navigation-menu-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('navigation-option-profile')));
    await tester.pumpAndSettle();

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

  testWidgets('skips initial setup wizard and marks first launch completed', (
    tester,
  ) async {
    final onboardingStore = _FakeOnboardingPreferenceStore(hasCompleted: false);

    await tester.pumpWidget(
      WorkHoursApp(
        dashboardService: DashboardService(repository: _FakeDashboardRepository()),
        appUpdateService: _CountingAppUpdateService(),
        updateReminderStore: _FakeUpdateReminderStore(),
        onboardingPreferenceStore: onboardingStore,
        themePreferenceStore: _FakeThemePreferenceStore(),
        workdayStartStore: _FakeWorkdayStartStore(),
        supportTicketStore: _FakeSupportTicketStore(),
        hasCompletedInitialSetup: false,
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Configurazione iniziale 1/3'), findsNothing);
    expect(find.text('Configurazione iniziale 2/3'), findsNothing);
    expect(find.text('Configurazione iniziale 3/3'), findsNothing);
    expect(onboardingStore.markCompletedCalls, 1);
  });

  testWidgets('submits a support ticket from the app', (tester) async {
    final repository = _FakeDashboardRepository();
    await tester.binding.setSurfaceSize(const Size(1400, 2200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      WorkHoursApp(
        dashboardService: DashboardService(repository: repository),
        appUpdateService: _CountingAppUpdateService(),
        updateReminderStore: _FakeUpdateReminderStore(),
        onboardingPreferenceStore: _FakeOnboardingPreferenceStore(
          hasCompleted: true,
        ),
        themePreferenceStore: _FakeThemePreferenceStore(),
        workdayStartStore: _FakeWorkdayStartStore(),
        supportTicketStore: _FakeSupportTicketStore(),
        hasCompletedInitialSetup: true,
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('navigation-menu-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('navigation-option-ticket')));
    await tester.pumpAndSettle();

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

class _FakeAppUpdateService implements AppUpdateService {
  @override
  Future<AppUpdate?> checkForUpdate() async {
    return const AppUpdate(
      currentVersion: '0.1.0',
      latestVersion: '0.1.1',
      downloadUrl: 'https://example.invalid/app-release.apk',
      releasePageUrl: 'https://example.invalid/releases/latest',
    );
  }

  @override
  Future<bool> openUpdate(AppUpdate update) async {
    return true;
  }

  @override
  Future<DownloadedAppUpdate> downloadUpdate(
    AppUpdate update, {
    required UpdateDownloadProgressCallback onProgress,
  }) async {
    onProgress(const UpdateDownloadProgress(receivedBytes: 10, totalBytes: 10));
    return DownloadedAppUpdate(
      update: update,
      filePath: '/tmp/app-release.apk',
      fileName: 'app-release.apk',
      bytesDownloaded: 10,
    );
  }

  @override
  Future<UpdateInstallResult> installUpdate(DownloadedAppUpdate update) async {
    return UpdateInstallResult.started;
  }
}

class _CountingAppUpdateService implements AppUpdateService {
  int checkCount = 0;

  @override
  Future<AppUpdate?> checkForUpdate() async {
    checkCount += 1;
    return null;
  }

  @override
  Future<bool> openUpdate(AppUpdate update) async {
    return true;
  }

  @override
  Future<DownloadedAppUpdate> downloadUpdate(
    AppUpdate update, {
    required UpdateDownloadProgressCallback onProgress,
  }) async {
    onProgress(const UpdateDownloadProgress(receivedBytes: 10, totalBytes: 10));
    return DownloadedAppUpdate(
      update: update,
      filePath: '/tmp/app-release.apk',
      fileName: 'app-release.apk',
      bytesDownloaded: 10,
    );
  }

  @override
  Future<UpdateInstallResult> installUpdate(DownloadedAppUpdate update) async {
    return UpdateInstallResult.started;
  }
}

class _ManualCheckAppUpdateService implements AppUpdateService {
  int checkCount = 0;

  @override
  Future<AppUpdate?> checkForUpdate() async {
    checkCount += 1;
    return const AppUpdate(
      currentVersion: '0.1.0',
      latestVersion: '0.1.1',
      downloadUrl: 'https://example.com/app-release.apk',
      releasePageUrl: 'https://example.com/release',
    );
  }

  @override
  Future<bool> openUpdate(AppUpdate update) async {
    return true;
  }

  @override
  Future<DownloadedAppUpdate> downloadUpdate(
    AppUpdate update, {
    required UpdateDownloadProgressCallback onProgress,
  }) async {
    onProgress(const UpdateDownloadProgress(receivedBytes: 10, totalBytes: 10));
    return DownloadedAppUpdate(
      update: update,
      filePath: '/tmp/app-release.apk',
      fileName: 'app-release.apk',
      bytesDownloaded: 10,
    );
  }

  @override
  Future<UpdateInstallResult> installUpdate(DownloadedAppUpdate update) async {
    return UpdateInstallResult.started;
  }
}

class _FakeUpdateReminderStore implements UpdateReminderStore {
  final List<String> remindedLaterVersions = [];
  final List<String> deferredAfterOpeningVersions = [];

  @override
  Future<void> deferAfterOpening(AppUpdate update) async {
    deferredAfterOpeningVersions.add(update.latestVersion);
  }

  @override
  Future<void> remindLater(AppUpdate update) async {
    remindedLaterVersions.add(update.latestVersion);
  }

  @override
  Future<bool> shouldPromptFor(AppUpdate update) async {
    return true;
  }
}

class _FakeThemePreferenceStore implements ThemePreferenceStore {
  final List<ThemeMode> savedThemeModes = [];
  AppAppearanceSettings settings = AppAppearanceSettings.defaults;

  @override
  Future<ThemeMode> loadThemeMode() async {
    return settings.themeMode;
  }

  @override
  Future<AppAppearanceSettings> loadAppearanceSettings() async {
    return settings;
  }

  @override
  Future<void> saveThemeMode(ThemeMode themeMode) async {
    settings = settings.copyWith(themeMode: themeMode);
    savedThemeModes.add(themeMode);
  }

  @override
  Future<void> saveAppearanceSettings(AppAppearanceSettings settings) async {
    this.settings = settings;
    savedThemeModes.add(settings.themeMode);
  }
}

class _FakeWorkdayStartStore implements WorkdayStartStore {
  _FakeWorkdayStartStore({Map<String, WorkdaySession>? initialValues})
    : _values = {...?initialValues};

  final Map<String, WorkdaySession> _values;

  @override
  Future<void> clearSession(String isoDate) async {
    _values.remove(isoDate);
  }

  @override
  Future<WorkdaySession?> loadSession(String isoDate) async {
    return _values[isoDate];
  }

  @override
  Future<void> saveSession(String isoDate, WorkdaySession session) async {
    _values[isoDate] = session;
  }
}

class _FakeOnboardingPreferenceStore implements OnboardingPreferenceStore {
  _FakeOnboardingPreferenceStore({required this.hasCompleted});

  final bool hasCompleted;
  int markCompletedCalls = 0;

  @override
  Future<bool> hasCompletedInitialSetup() async {
    return hasCompleted;
  }

  @override
  Future<void> markInitialSetupCompleted() async {
    markCompletedCalls += 1;
  }
}

class _FakeSupportTicketStore implements SupportTicketStore {
  final List<TrackedSupportTicket> _tickets = [];

  @override
  Future<List<TrackedSupportTicket>> loadTrackedTickets() async {
    return List<TrackedSupportTicket>.from(_tickets);
  }

  @override
  Future<void> saveTrackedTickets(List<TrackedSupportTicket> tickets) async {
    _tickets
      ..clear()
      ..addAll(tickets);
  }

  @override
  Future<void> upsertTrackedTicket(TrackedSupportTicket ticket) async {
    _tickets.removeWhere((entry) => entry.id == ticket.id);
    _tickets.insert(0, ticket);
  }

  @override
  Future<void> markAdminRepliesSeen({
    required String ticketId,
    required int adminReplyCount,
  }) async {
    final index = _tickets.indexWhere((entry) => entry.id == ticketId);
    if (index < 0) {
      return;
    }

    _tickets[index] = _tickets[index].copyWith(
      lastSeenAdminReplyCount: adminReplyCount,
    );
  }

  @override
  Future<void> markAdminRepliesNotified({
    required String ticketId,
    required int adminReplyCount,
  }) async {
    final index = _tickets.indexWhere((entry) => entry.id == ticketId);
    if (index < 0) {
      return;
    }

    _tickets[index] = _tickets[index].copyWith(
      lastNotifiedAdminReplyCount: adminReplyCount,
    );
  }
}

class _FakeDashboardRepository implements DashboardRepository {
  _FakeDashboardRepository({
    Map<String, ScheduleOverride>? initialScheduleOverrides,
  }) : _scheduleOverridesByDate = {
         '2026-03-04': const ScheduleOverride(
           id: 'override-1',
           date: '2026-03-04',
           targetMinutes: 240,
           startTime: '09:00',
           endTime: '13:30',
           breakMinutes: 30,
           note: 'Scambio turno',
         ),
         ...?initialScheduleOverrides,
       };

  final Map<String, ScheduleOverride> _scheduleOverridesByDate;
  final Map<String, SupportTicketThread> _ticketThreadsById = {};
  String? savedFullName;
  int? savedDailyTargetMinutes;
  WeekdayTargetMinutes? savedWeekdayTargetMinutes;
  WeekdaySchedule? savedWeekdaySchedule;
  UserWorkRules? savedWorkRules;
  SupportTicketCategory? submittedTicketCategory;
  String? submittedTicketName;
  String? submittedTicketEmail;
  String? submittedTicketSubject;
  String? submittedTicketMessage;
  String? submittedTicketAppVersion;

  @override
  Future<DashboardSnapshot> addLeaveEntry({
    required String date,
    required int minutes,
    required LeaveType type,
    String? note,
    required String month,
  }) {
    return loadSnapshot(month: month);
  }

  @override
  Future<DashboardSnapshot> addWorkEntry({
    required String date,
    required int minutes,
    String? note,
    required String month,
  }) {
    return loadSnapshot(month: month);
  }

  @override
  Future<DashboardSnapshot> loadSnapshot({required String month}) async {
    final weekdayTargetMinutes =
        savedWeekdayTargetMinutes ??
        WeekdayTargetMinutes(
          monday: 480,
          tuesday: 360,
          wednesday: 360,
          thursday: 480,
          friday: 480,
          saturday: 0,
          sunday: 0,
        );
    final weekdaySchedule =
        savedWeekdaySchedule ??
        WeekdaySchedule(
          monday: DaySchedule(
            targetMinutes: 480,
            startTime: '08:30',
            endTime: '17:00',
            breakMinutes: 30,
          ),
          tuesday: DaySchedule(
            targetMinutes: 360,
            startTime: '08:30',
            endTime: '15:00',
            breakMinutes: 30,
          ),
          wednesday: DaySchedule(
            targetMinutes: 360,
            startTime: '08:30',
            endTime: '15:00',
            breakMinutes: 30,
          ),
          thursday: DaySchedule(
            targetMinutes: 480,
            startTime: '08:30',
            endTime: '17:00',
            breakMinutes: 30,
          ),
          friday: DaySchedule(
            targetMinutes: 480,
            startTime: '08:30',
            endTime: '17:00',
            breakMinutes: 30,
          ),
          saturday: DaySchedule(targetMinutes: 0),
          sunday: DaySchedule(targetMinutes: 0),
        );
    final workRules =
        savedWorkRules ??
        UserWorkRules.unbounded(
          expectedDailyMinutes: savedDailyTargetMinutes ?? 450,
          minimumBreakMinutes: 30,
        );
    return DashboardSnapshot(
      profile: UserProfile(
        id: 'default-profile',
        fullName: savedFullName ?? 'Carlo Bonvicini',
        useUniformDailyTarget: false,
        dailyTargetMinutes: savedDailyTargetMinutes ?? 450,
        weekdayTargetMinutes: weekdayTargetMinutes,
        weekdaySchedule: weekdaySchedule,
        workRules: workRules,
      ),
      summary: MonthlySummary.fromTotals(
        month: month,
        expectedMinutes: 10350,
        workedMinutes: 900,
        leaveMinutes: 60,
        rules: workRules,
      ),
      workEntries: const [
        WorkEntry(
          id: '1',
          date: '2026-03-03',
          minutes: 420,
          note: 'Sprint mobile',
        ),
      ],
      leaveEntries: const [
        LeaveEntry(
          id: 'leave-1',
          date: '2026-03-04',
          minutes: 60,
          type: LeaveType.permit,
          note: 'Visita medica',
        ),
      ],
      scheduleOverrides: _scheduleOverridesByDate.values.toList(
        growable: false,
      ),
      apiBaseUrl: 'http://localhost:8080/',
    );
  }

  @override
  Future<DashboardSnapshot> saveProfile({
    required String fullName,
    required bool useUniformDailyTarget,
    required int dailyTargetMinutes,
    required WeekdayTargetMinutes weekdayTargetMinutes,
    required WeekdaySchedule weekdaySchedule,
    required UserWorkRules workRules,
    required String month,
  }) {
    savedFullName = fullName;
    savedDailyTargetMinutes = dailyTargetMinutes;
    savedWeekdayTargetMinutes = weekdayTargetMinutes;
    savedWeekdaySchedule = weekdaySchedule;
    savedWorkRules = workRules;
    return loadSnapshot(month: month);
  }

  @override
  Future<DashboardSnapshot> saveScheduleOverride({
    required String date,
    required int targetMinutes,
    String? startTime,
    String? endTime,
    required int breakMinutes,
    String? note,
    required String month,
  }) {
    _scheduleOverridesByDate[date] = ScheduleOverride(
      id: 'override-$date',
      date: date,
      targetMinutes: targetMinutes,
      startTime: startTime,
      endTime: endTime,
      breakMinutes: breakMinutes,
      note: note,
    );
    return loadSnapshot(month: month);
  }

  @override
  Future<DashboardSnapshot> removeScheduleOverride({
    required String date,
    required String month,
  }) {
    _scheduleOverridesByDate.remove(date);
    return loadSnapshot(month: month);
  }

  @override
  Future<SupportTicketThread> submitSupportTicket({
    required SupportTicketCategory category,
    String? name,
    String? email,
    required String subject,
    required String message,
    String? appVersion,
    List<SupportTicketUploadAttachment> attachments = const [],
  }) async {
    submittedTicketCategory = category;
    submittedTicketName = name;
    submittedTicketEmail = email;
    submittedTicketSubject = subject;
    submittedTicketMessage = message;
    submittedTicketAppVersion = appVersion;
    final thread = SupportTicketThread(
      id: 'ticket-1',
      category: category,
      status: SupportTicketStatus.newTicket,
      subject: subject,
      message: message,
      createdAt: DateTime(2026, 3, 20, 9, 0),
      updatedAt: DateTime(2026, 3, 20, 9, 0),
      attachments: attachments
          .asMap()
          .entries
          .map(
            (entry) => SupportTicketAttachment(
              id: 'attachment-${entry.key + 1}',
              fileName: entry.value.fileName,
              contentType: entry.value.contentType,
              sizeBytes: entry.value.sizeBytes,
            ),
          )
          .toList(growable: false),
      replies: const [],
      name: name,
      email: email,
      appVersion: appVersion,
    );
    _ticketThreadsById[thread.id] = thread;
    return thread;
  }

  @override
  Future<SupportTicketThread> fetchSupportTicket({
    required String ticketId,
  }) async {
    return _ticketThreadsById[ticketId] ??
        SupportTicketThread(
          id: 'ticket-1',
          category: SupportTicketCategory.support,
          status: SupportTicketStatus.newTicket,
          subject: 'Supporto',
          message: 'Messaggio',
          createdAt: DateTime(2026, 3, 20, 9),
          updatedAt: DateTime(2026, 3, 20, 9),
          attachments: const [],
          replies: [],
        );
  }

  @override
  Future<SupportTicketThread> replyToSupportTicket({
    required String ticketId,
    required String message,
  }) async {
    final currentThread = await fetchSupportTicket(ticketId: ticketId);
    final updatedThread = SupportTicketThread(
      id: currentThread.id,
      category: currentThread.category,
      status: SupportTicketStatus.inProgress,
      subject: currentThread.subject,
      message: currentThread.message,
      createdAt: currentThread.createdAt,
      updatedAt: DateTime(2026, 3, 20, 9, 30),
      attachments: currentThread.attachments,
      replies: [
        ...currentThread.replies,
        SupportTicketReply(
          id: 'reply-1',
          author: 'user',
          message: 'Grazie',
          createdAt: DateTime(2026, 3, 20, 9, 30),
        ),
      ],
      name: currentThread.name,
      email: currentThread.email,
      appVersion: currentThread.appVersion,
    );
    _ticketThreadsById[ticketId] = updatedThread;
    return updatedThread;
  }
}
