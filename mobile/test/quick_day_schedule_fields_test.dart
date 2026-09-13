import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_hours_mobile/presentation/home/widgets/calendar/quick_day_schedule_fields.dart';

void main() {
  Future<void> pumpFields(
    WidgetTester tester, {
    String endTimeText = '',
    String plannedEndTimeText = '',
    String suggestedExitLabel = '--:--',
    bool hasProgrammedExit = false,
    bool hasTheoreticalExit = false,
    bool hasPendingExitConfirmation = false,
    bool isDayOff = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QuickDayScheduleFields(
            targetText: '8:00',
            startTimeText: '09:00',
            endTimeText: endTimeText,
            plannedStartTimeText: '09:00',
            plannedEndTimeText: plannedEndTimeText,
            suggestedExitLabel: suggestedExitLabel,
            breakMinutes: 0,
            showEndTime: true,
            showBreakMinutes: true,
            isDayOff: isDayOff,
            hasResultContext: false,
            hasProgrammedExit: hasProgrammedExit,
            hasTheoreticalExit: hasTheoreticalExit,
            hasPendingExitConfirmation: hasPendingExitConfirmation,
            isUsingStandardWorkTarget: true,
            onPickTargetMinutes: () async {},
            onPickStartTime: () async {},
            onPickEndTime: () async {},
            onPickBreakMinutes: () async {},
            onConfirmTheoreticalExit: () async {},
          ),
        ),
      ),
    );
  }

  void expectNoLegacyExitLabels() {
    // I nomi di prima raccontavano da dove arriva il numero: non sono un
    // problema di chi usa l'app.
    expect(find.text('Uscita programmata'), findsNothing);
    expect(find.text('Uscita teorica'), findsNothing);
  }

  group('etichetta dell uscita', () {
    testWidgets('l uscita del piano si chiama prevista', (tester) async {
      await pumpFields(tester, plannedEndTimeText: '17:00');

      expect(find.text('Uscita prevista'), findsOneWidget);
      expect(find.text('17:00'), findsOneWidget);
      expectNoLegacyExitLabels();
    });

    testWidgets('anche quella calcolata su entrata e ore si chiama prevista', (
      tester,
    ) async {
      await pumpFields(
        tester,
        hasTheoreticalExit: true,
        suggestedExitLabel: '17:30',
      );

      expect(find.text('Uscita prevista'), findsOneWidget);
      expect(find.text('17:30'), findsOneWidget);
      // La differenza la fa l'azione, non un nome diverso.
      expect(find.text('Conferma'), findsOneWidget);
      expectNoLegacyExitLabels();
    });

    testWidgets('anche quella in attesa di conferma si chiama prevista', (
      tester,
    ) async {
      await pumpFields(
        tester,
        endTimeText: '18:00',
        hasPendingExitConfirmation: true,
      );

      expect(find.text('Uscita prevista'), findsOneWidget);
      expect(find.text('Conferma'), findsOneWidget);
      expectNoLegacyExitLabels();
    });

    testWidgets('un orario gia registrato si chiama solo Uscita', (
      tester,
    ) async {
      await pumpFields(tester, endTimeText: '17:04');

      expect(find.text('Uscita'), findsOneWidget);
      expect(find.text('Uscita prevista'), findsNothing);
      expect(find.text('17:04'), findsOneWidget);
      expect(find.text('Conferma'), findsNothing);
      expectNoLegacyExitLabels();
    });

    testWidgets('una giornata libera non propone un uscita', (tester) async {
      await pumpFields(tester, isDayOff: true, plannedEndTimeText: '17:00');

      expect(find.text('Uscita'), findsOneWidget);
      expect(find.text('Uscita prevista'), findsNothing);
      expect(find.text('--:--'), findsWidgets);
    });
  });
}
