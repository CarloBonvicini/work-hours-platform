// Regole di permessi e banche ore nelle impostazioni.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/app_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'edits custom permission rules and shows configured monitoring summary',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(900, 2200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await pumpWorkHoursApp(tester);

      await tester.pumpAndSettle();
      if (find.text('Ricordamelo piu tardi').evaluate().isNotEmpty) {
        await tester.tap(find.text('Ricordamelo piu tardi'));
        await tester.pumpAndSettle();
      }

      await openHomeSection(tester, 'workSettings');

      await tester.scrollUntilVisible(
        find.text('Regole permessi'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      if (find.text('Aggiungi permesso').evaluate().isEmpty) {
        await tester.tap(
          find.byKey(const ValueKey('work-settings-permissions-toggle-button')),
        );
        await tester.pumpAndSettle();
      }

      await tester.tap(find.text('Aggiungi permesso'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find
            .descendant(
              of: find.byType(AlertDialog),
              matching: find.byType(TextField),
            )
            .first,
        'P36',
      );
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Salva'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('P36'), findsOneWidget);
      expect(find.text('Monitoraggio impostazioni'), findsOneWidget);
      expect(find.textContaining('Movimenti configurati:'), findsOneWidget);

      await tester.tap(find.byTooltip('Modifica P36'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find
            .descendant(
              of: find.byType(AlertDialog),
              matching: find.byType(TextField),
            )
            .first,
        'P36 aggiornato',
      );
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Salva'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('P36 aggiornato'), findsOneWidget);
      expect(find.text('P36'), findsNothing);
    },
  );
}
