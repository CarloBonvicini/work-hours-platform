# Backend AGENTS

## Obiettivo
Evolvere il backend senza aumentare accoppiamento e complessita.

## Regole backend
- Le route devono restare sottili: validazione input + orchestrazione.
- La logica di business deve stare in moduli dominio dedicati.
- La persistenza deve rimanere nel layer `data/`.
- Evita HTML/JS inline di grandi dimensioni nei route handler: estrai in moduli separati quando tocchi aree ampie.

## Limiti lint
- Configurati in `eslint.config.js`.
- Regole bloccanti su `src/**`:
  - `max-lines` (400)
  - `max-lines-per-function` (40)
  - `complexity` (10)
  - `max-depth` (4)
- Alcuni file legacy sono in eccezione temporanea (vedi config).

## Checklist prima del push
- `npm run lint`
- `npm test`
- `npm run build`

## Test
- Ogni nuova API deve avere o aggiornare test in `test/`.
- Coprire almeno: caso felice, validazione input, autorizzazione/permessi, error path principale.
