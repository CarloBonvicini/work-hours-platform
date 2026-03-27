import 'package:flutter_test/flutter_test.dart';
import 'package:work_hours_mobile/presentation/home/update_release_notes_parser.dart';

void main() {
  test('preferisce la sezione novita per l utente quando presente', () {
    final notes = '''
## Dettagli tecnici
- chore: harden mobile release pipeline
- fix: update backend api path

## Novita per te
- Agenda settimanale piu leggibile
- Ticket con foto dalla galleria
''';

    final items = resolveUserFacingReleaseNotes(notes);

    expect(
      items,
      equals([
        'Agenda settimanale piu leggibile',
        'Ticket con foto dalla galleria',
      ]),
    );
  });

  test('ripulisce markdown, link e riferimenti tecnici finali', () {
    final notes =
        '- [Vista Oggi piu chiara](https://example.com) (#12) by @carlo';

    final items = resolveUserFacingReleaseNotes(notes);

    expect(items, equals(['Vista Oggi piu chiara']));
  });

  test(
    'usa fallback non tecnico quando le note contengono solo testo tecnico',
    () {
      final notes = '''
fix: align backend api validation
Update workflow mobile-release.yml
Android APK build 1.2.3.
''';

      final items = resolveUserFacingReleaseNotes(notes);

      expect(
        items,
        equals(['Miglioramenti generali e correzioni di stabilita.']),
      );
    },
  );

  test('limita a cinque righe ed elimina duplicati', () {
    final notes = '''
- Nuovo riepilogo giornaliero
- Nuovo riepilogo giornaliero
- Migliorata lettura del saldo mese
- Migliorata schermata ticket
- Nuove etichette piu chiare
- Navigazione piu veloce tra i giorni
- Correzione visuale calendario
''';

    final items = resolveUserFacingReleaseNotes(notes);

    expect(
      items,
      equals([
        'Nuovo riepilogo giornaliero',
        'Migliorata lettura del saldo mese',
        'Migliorata schermata ticket',
        'Nuove etichette piu chiare',
        'Navigazione piu veloce tra i giorni',
      ]),
    );
  });
}
