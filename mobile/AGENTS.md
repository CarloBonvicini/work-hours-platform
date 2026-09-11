# Mobile AGENTS

## Obiettivo
Mantenere UI e logica Flutter coerenti, prevedibili e testabili.

## Regole mobile
- Separare widget UI da logica/calcoli quando la schermata cresce.
- Evitare file-schermata monolitici: preferire componenti piccoli riusabili.
- Non introdurre logica business complessa dentro widget build.
- Le impostazioni utente e sincronizzazione cloud devono restare consistenti.

## Qualita
- Ogni modifica deve passare:
  - `flutter analyze`
  - `flutter test`
- Se una feature tocca calcoli orari/saldi, aggiungere o aggiornare test dedicati.

## UX guardrail
- Stato vuoto sempre guidato (no interfacce ambigue).
- Le azioni principali devono essere chiaramente cliccabili.
- Evitare testo tecnico lato utente finale.

## Struttura della home (`lib/presentation/home/`)
- `home_screen.dart`: `HomeScreen`, la base astratta `_HomeScreenStateBase` (campi condivisi + firme dei metodi usati tra aree diverse) e `_HomeScreenState` (solo ciclo di vita e `build`).
- `home_state/`: un mixin per area (ticket, account cloud, aggiornamenti, timbratura, bozza orario, agenda, impostazioni, calendario, consuntivo...) come file `part` della stessa libreria. Nuova logica di stato va nel mixin dell'area giusta; se un metodo serve a piu' aree, dichiararne la firma nella base.
- `models/`: modelli di vista (CalendarDay, DayMetrics, AgendaRange, HomeSection...).
- `logic/`: funzioni pure testabili (saldi giornalieri, insight editor rapido, segmenti agenda, etichette, stato timbratura).
- `widgets/<area>/`: widget pubblici per area (calendar, agenda, settings, overview, support, update, shared).
- Non riportare codice dentro `home_screen.dart`: e' la regia, non un contenitore.
