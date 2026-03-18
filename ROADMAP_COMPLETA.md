# Roadmap Completa

## Visione

Costruire una app mobile Flutter per gestione ore, ferie e permessi con architettura locale-first, backend leggero evolutivo, e deploy robusto su server debole tramite CI/CD e immagini Docker. La prima milestone distributiva deve essere un APK scaricabile direttamente da GitHub Releases.

## Principi guida

1. Separazione chiara tra client, backend e infrastruttura.
2. Server con carico minimo: no build pesanti in macchina.
3. Deploy tramite artifact/immagini versionate.
4. Crescita progressiva: v1 semplice, evoluzione incrementale.

## Fase 1 - Prodotto minimo (MVP)

### Obiettivo

Definire con precisione cosa entra in v1 e cosa e rinviato.

### In scope v1

1. Profilo utente
2. Impostazioni monte ore
3. Inserimento ore giornaliero
4. Ferie e permessi
5. Saldo automatico
6. Dashboard mensile
7. Notifiche locali
8. Export PDF
9. APK Android pubblicato su GitHub Releases con istruzioni minime di installazione

### Out of scope v1

1. Integrazioni esterne
2. Sync multi-device avanzato
3. Push notification server-side
4. Amministrazione multiutente avanzata

### Output fase

1. Documento requisiti v1 firmato
2. Lista backlog v1/v2 separata

## Fase 2 - Modello dati e architettura app

### Obiettivo

Bloccare dominio e regole core prima delle UI complesse.

### Entita minime

1. `User`
2. `Profile`
3. `WorkEntry`
4. `LeaveEntry`
5. `MonthlySummary`
6. `NotificationSettings`
7. `ExportJob` (o struttura report equivalente)

### Architettura Flutter consigliata

1. `presentation/`
2. `application/`
3. `domain/`
4. `data/`

### Output fase

1. Schema dati v1
2. Contratti tra layer
3. Regole calcolo documentate

## Fase 3 - UX e flussi principali

### Obiettivo

Disegnare i percorsi chiave prima dello sviluppo massivo.

### Wireframe da produrre

1. Onboarding
2. Creazione profilo
3. Home dashboard
4. Inserimento giornata
5. Storico
6. Export PDF
7. Impostazioni notifiche

### Output fase

1. Wireframe validati
2. Flussi approvati per Sprint 1 e 2

## Fase 4 - Backend minimo e isolamento server

### Obiettivo

Predisporre backend pronto all evoluzione senza complicare la v1.

### Scope backend iniziale

1. Health endpoint
2. Endpoint profilo
3. Endpoint work entries
4. Endpoint leave entries
5. Backup base

### Isolamento infrastruttura

1. Directory progetto dedicata
2. Container dedicati
3. Env file dedicati
4. Network Docker chiara
5. Riuso DB esistente solo se compatibile (engine, backup, isolamento schema, carico)

### Output fase

1. API v1 funzionante
2. Contratto API documentato
3. Deploy locale in container

## Fase 5 - Containerizzazione e operativita

### Obiettivo

Rendere il deploy ripetibile, osservabile e stabile.

### Componenti

1. `Dockerfile` backend
2. `docker-compose.yml`
3. `.env` per ambiente
4. Volumi persistenti dove necessari
5. Restart policy + healthcheck

### Output fase

1. Avvio ambiente con `docker compose up -d`
2. Procedure restart/rollback minime

## Fase 6 - CI/CD completo

### Obiettivo

Automatizzare quality gate e deploy evitando build in server.

### CI

1. Trigger su push e pull request
2. Lint
3. Test
4. Build

### CD consigliato

1. Build immagine in GitHub Actions
2. Push su GHCR
3. Deploy su server via SSH:
   - `docker compose pull`
   - `docker compose up -d`

### Segreti da configurare

1. `DEPLOY_HOST`
2. `DEPLOY_USER`
3. `DEPLOY_SSH_KEY`
4. `DEPLOY_PATH`

### Output fase

1. Deploy automatico su merge in `main`
2. Tempo deploy ridotto e carico server minimo

## Fase 7 - Mobile CI e release

### Obiettivo

Separare chiaramente deploy backend e rilascio app mobile con distribuzione via GitHub Releases.

### Pipeline mobile

1. `flutter analyze`
2. `flutter test`
3. Build Android artifact
4. Build iOS in runner macOS (quando necessario)
5. Pubblicazione APK su GitHub Releases

### Output fase

1. Artifact mobile riproducibili
2. Processo release controllato
3. APK versionato disponibile su GitHub Releases

## Fase 8 - Osservabilita minima

### Obiettivo

Capire subito quando qualcosa non funziona.

### Azioni

1. Log applicativi chiari (`info`, `warning`, `error`)
2. Endpoint `/health`
3. Healthcheck container
4. Alert base (successivo: email/Telegram)

### Output fase

1. Triage errori rapido
2. Diagnostica essenziale disponibile

## Fase 9 - Sicurezza minima

### Obiettivo

Ridurre superficie di rischio gia dalla v1.

### Azioni

1. Separazione ambienti `dev` e `prod`
2. Utente server dedicato
3. Chiavi SSH dedicate
4. Nessuna credenziale in repository
5. Repository private e policy accessi minima

### Output fase

1. Baseline sicurezza operativa

## Sequenza sprint consigliata

### Sprint 1 - Fondamenta prodotto e app

1. Definizione MVP finale
2. Wireframe principali
3. Setup Flutter
4. Definizione canale distribuzione con GitHub Releases
5. Prima build Android distribuibile
6. Modelli dati
7. Profilo utente
8. Inserimento ore
9. Motore calcolo base
10. Dashboard base

### Sprint 2 - Funzioni core utente

1. Ferie e permessi
2. Notifiche locali
3. Export PDF
4. Test unita sul motore calcolo

### Sprint 3 - Backend e container

1. API minima completa
2. Persistenza backend
3. Containerizzazione
4. Compose server
5. Gestione env/segreti

### Sprint 4 - CI/CD e messa in esercizio

1. Workflow CI consolidati
2. Build/publish immagini
3. Deploy automatico
4. Healthcheck e rollback manuale minimo

## Milestone pratiche

1. `M1`: setup monorepo + backend health + test verdi
2. `M2`: mobile bootstrap + primo APK pubblicato su GitHub Releases
3. `M3`: API v1 profile/work/leave
4. `M4`: deploy automatico su server con pull+restart
5. `M5`: rilascio beta interna mobile

## Rischi principali e mitigazioni

1. Rischio: server debole saturato
   - Mitigazione: build solo in CI, server solo pull/restart
2. Rischio: scope creep in v1
   - Mitigazione: backlog v2 separato e congelamento scope sprint
3. Rischio: regressioni calcolo ore
   - Mitigazione: test unita su regole dominio
4. Rischio: deploy fragile
   - Mitigazione: healthcheck, script idempotenti, rollback minimo

## KPI minimi di avanzamento

1. Percentuale test backend passati
2. Lead time da merge a deploy
3. Crash rate app in beta
4. Tempo medio per diagnosi incident (MTTD base)
