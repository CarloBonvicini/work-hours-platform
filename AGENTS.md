# AGENTS.md

## Obiettivo
Mantieni Work Hours Platform modulare, leggibile e facile da evolvere, evitando nuovo debito tecnico.

## Struttura repository
- `backend/`: API Fastify + persistenza.
- `mobile/`: client Flutter.
- `infra/`: artefatti runtime/deploy.

## Regole strutturali globali
- Non creare nuovi file monolitici.
- Evita moduli generici tipo `utils`/`manager` che accentrano logica eterogenea.
- UI, orchestrazione, business logic e persistenza devono rimanere separate.
- Si splitta quando un file mescola responsabilita, non quando un contatore supera una soglia.

## Soglie di dimensione
- Riferimento: 400 righe per file, 40 per funzione (righe vuote e commenti esclusi).
- Backend: sono bloccanti, le applica il lint (`backend/eslint.config.js`).
- Mobile: nessun enforcement automatico e molti file sono gia oltre. Valgono come direzione:
  i file nuovi nascono sotto soglia, quelli che tocchi non devono crescere oltre.
- Non spendere un task a spezzare un file solo perche ha passato la soglia: se la
  responsabilita e una sola, lascialo e dillo nel task.

## Anti-monolite
- E vietato aggiungere nuove feature in file legacy gia oversize senza valutare prima decomposizione.
- Eccezioni backend: l'elenco autorevole e `LEGACY_OVERSIZED_FILES` in `backend/eslint.config.js`.
  Tienilo allineato la', non duplicarlo qui.
- Mobile: non esiste una lista e diversi file sono oversize. Regola operativa: non peggiorarli.
  Se ne tocchi uno, o lo lasci come lo hai trovato o lo riduci.
- Se tocchi file legacy, fai modifiche minime e proponi split incrementale nel task.

## Modalita di lavoro
Per ogni task:
1. identifica i file da toccare;
2. valuta se conviene creare/modificare un modulo dedicato;
3. implementa in modo incrementale;
4. aggiorna/aggiungi test;
5. verifica lint, test e build prima del push.

## Qualita e gate
- Nessun warning o errore nei controlli richiesti.
- Backend: `npm run lint`, `npm test`, `npm run build`.
- Mobile: `flutter analyze`, `flutter test`.
- La CI mobile usa una versione Flutter pinnata (`FLUTTER_VERSION` in `.github/workflows/mobile-ci.yml` e `mobile-release.yml`): gli aggiornamenti del tag si fanno deliberatamente, verificando prima analyze/test.
- In caso di compromesso strutturale, esplicitalo e proponi piano di refactor.

## Override locali
- Leggere sempre anche:
  - `backend/AGENTS.md`
  - `mobile/AGENTS.md`
