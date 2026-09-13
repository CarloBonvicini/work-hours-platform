# Mobile AGENTS

## Obiettivo
Mantenere UI e logica Flutter coerenti, prevedibili e testabili.

## Regole mobile
- Separare widget UI da logica/calcoli quando la schermata cresce.
- Evitare file-schermata monolitici: preferire componenti piccoli riusabili.
- Non introdurre logica business complessa dentro widget build.
- Un `build` lungo si accorcia estraendo widget, non funzioni helper a cui passare il
  `BuildContext`: la soglia delle 40 righe per funzione non si applica ai `build`.
- Le impostazioni utente e sincronizzazione cloud devono restare consistenti.

## Previsto e registrato
- L'orario previsto (piano settimanale, valori derivati, uscite suggerite) serve a mostrare
  e a proporre. Non deve mai entrare in ore lavorate, saldi, straordinari o messaggi tipo
  "uscita registrata": quelli dipendono solo da timbratura e registrazioni salvate.
- Prima di riempire un campo con un valore derivato, controlla chi altro legge quel campo:
  un orario messo "per comodita" diventa in silenzio un dato di fatto altrove.

## Qualita
- Ogni modifica deve passare:
  - `flutter analyze`
  - `flutter test`
- Se una feature tocca calcoli orari/saldi, aggiungere o aggiornare test dedicati.
- L'SDK Flutter puo non essere installato nell'ambiente di lavoro. In quel caso clonalo
  alla versione pinnata in `.github/workflows/mobile-ci.yml` e mettilo in PATH:
  `git clone --depth 1 -b "$FLUTTER_VERSION" https://github.com/flutter/flutter.git`.
  Non aggiornare il tag per far girare i controlli e non committare `pubspec.lock`
  se a cambiarlo e stato solo `flutter pub get`.

## Struttura dei test (`test/`)
- `support/`: doppi di test condivisi (`fake_app_services.dart`,
  `fake_dashboard_repository.dart`) e `app_test_harness.dart`, che monta l'app con
  `pumpWorkHoursApp` e offre i gesti ricorrenti (chiusura dialogo aggiornamenti,
  apertura di una sezione).
- Un file di widget test per area (vista giorno, modifica rapida, timbratura,
  preferenze di layout, impostazioni orario, regole permessi, avvio app): niente
  file unico che raccoglie tutto.
- I test di logica pura restano affiancati al modulo che coprono.

## UX guardrail
- Stato vuoto guidato quando in quel punto c'e' davvero un'azione da fare. Se un blocco non
  ha nulla da mostrare e nulla di suo da fare, va tolto, non riempito di "Nessun dato".
- Niente blocchi che ripetono dati gia presenti nella stessa schermata.
- I campi che hanno un valore previsto arrivano precompilati e riconoscibili come previsione:
  chi lavora conferma, non reinserisce.
- Prima di togliere un blocco, verifica che le sue azioni restino raggiungibili dalla
  navigazione reale: alcune sezioni esistono nel codice ma non sono in `mainNavigationSections`.
- Le azioni principali devono essere chiaramente cliccabili.
- Evitare testo tecnico lato utente finale.

## Struttura della home (`lib/presentation/home/`)
- `home_screen.dart`: `HomeScreen`, la base astratta `_HomeScreenStateBase` (campi condivisi + firme dei metodi usati tra aree diverse) e `_HomeScreenState` (solo ciclo di vita e `build`).
- `home_state/`: un mixin per area (ticket, account cloud, aggiornamenti, timbratura, bozza orario, agenda, impostazioni, calendario, consuntivo...) come file `part` della stessa libreria. Nuova logica di stato va nel mixin dell'area giusta; se un metodo serve a piu' aree, dichiararne la firma nella base.
- `models/`: modelli di vista (CalendarDay, DayMetrics, AgendaRange, HomeSection...).
- `logic/`: funzioni pure testabili (saldi giornalieri, insight editor rapido, segmenti agenda, etichette, stato timbratura).
- `widgets/<area>/`: widget pubblici per area (calendar, agenda, settings, overview, support, update, shared).
- Non riportare codice dentro `home_screen.dart`: e' la regia, non un contenitore.
- Niente nuovi file sciolti nella radice di `home/`: quelli rimasti (`consuntivo_section.dart`,
  `initial_setup_dialog.dart`, ...) sono residui da riassorbire, non un posto dove aggiungere.
