# Cosa Abbiamo Fatto E Next Step

## Cosa abbiamo fatto

1. Monorepo creato con cartelle `mobile/`, `backend/`, `infra/`, `.github/workflows/`.
2. Backend base Node + Fastify pronto con endpoint `GET /health`.
3. CI backend (`backend-ci.yml`) e CI mobile (`mobile-ci.yml`) attive.
4. Deploy Docker preparato con `infra/docker-compose.yml` e `infra/deploy.sh`.
5. CD aggiornato a modello senza SSH:
   - build e push immagine su GHCR
   - deploy su runner self-hosted
6. Documentazione deploy aggiornata in `AUTO_DEPLOY_SETUP.md`.
7. Backend evoluto con store astratto e supporto runtime `memory` o `postgres`.
8. Test backend e build TypeScript verificati localmente.
9. Bootstrap Flutter completato dentro `mobile/` con struttura `presentation/application/domain/data`.
10. Workflow `Mobile Release` aggiunto per build e pubblicazione APK su GitHub Releases.
11. Branding mobile e identificatori applicativi allineati a `Work Hours Platform`.
12. Build APK Android `debug` e `release` verificate localmente.

## Stato attuale (18 marzo 2026)

1. Repository GitHub privato configurato e sincronizzato.
2. Backend API v1 funzionante con persistenza astratta e opzione Postgres.
3. Deploy pipeline pronta in versione self-hosted.
4. Secret richiesto per il runtime: `RUNTIME_ENV_FILE`.
5. Runner self-hosted da configurare/tenere online sul portatile.
6. Mobile bootstrapato: progetto Flutter presente, `analyze`, `test`, `build apk --debug` e `build apk --release` verdi in locale.
7. Priorita prodotto aggiornata: prima consegna utile = APK scaricabile direttamente da GitHub Releases.
8. `applicationId` Android impostato a `com.carlobonvicini.workhours`.
9. Il rilascio va comunque validato anche via GitHub Actions per confermare il workflow `Mobile Release`.

## Next step immediati

1. Eseguire la prima release APK da GitHub:
   - workflow `Mobile Release`
   - oppure push di tag `mobile-v0.1.0`
2. Collegare i dati reali del backend al client Flutter.
3. Ridurre la dimensione della build `debug` locale se diventa un problema operativo.
4. Configurare il runner in GitHub:
   - `Settings > Actions > Runners > New self-hosted runner`
5. Inserire il secret repository:
   - `RUNTIME_ENV_FILE`
6. Fare un push di test su `main`.
7. Verificare workflow `Backend CD` verde e container `api` in `Up`.
