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
