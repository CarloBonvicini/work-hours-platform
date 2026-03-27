# AGENTS.md

## Obiettivo
Mantieni Work Hours Platform modulare, leggibile e facile da evolvere, evitando nuovo debito tecnico.

## Struttura repository
- `backend/`: API Fastify + persistenza.
- `mobile/`: client Flutter.
- `infra/`: artefatti runtime/deploy.

## Regole strutturali globali
- Non creare nuovi file monolitici.
- Se un file supera 400 righe, preferisci split per responsabilita.
- Se una funzione supera 40 righe, estrai funzioni piu piccole.
- Evita moduli generici tipo `utils`/`manager` che accentrano logica eterogenea.
- UI, orchestrazione, business logic e persistenza devono rimanere separate.

## Anti-monolite
- E vietato aggiungere nuove feature in file legacy gia oversize senza valutare prima decomposizione.
- Eccezioni legacy attuali: `backend/src/app.ts`, `backend/src/data/postgres-store.ts`, `backend/src/domain/monthly-summary.ts`.
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
- In caso di compromesso strutturale, esplicitalo e proponi piano di refactor.

## Override locali
- Leggere sempre anche:
  - `backend/AGENTS.md`
  - `mobile/AGENTS.md`
