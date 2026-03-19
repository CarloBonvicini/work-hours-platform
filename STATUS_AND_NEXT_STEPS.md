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
13. Client Flutter collegato al backend reale per profilo, work entries e monthly summary.
14. Backend aggiornato con CORS configurabile per supportare il client anche da browser/desktop.
15. Client mobile aggiornato con controllo automatico delle nuove release e apertura del download APK da GitHub Releases.
16. Canale update produzione introdotto: il backend Linux puo servire feed update e APK da `infra/updates/`.

## Stato attuale (18 marzo 2026)

1. Repository GitHub privato configurato e sincronizzato.
2. Backend API v1 funzionante con persistenza astratta e opzione Postgres.
3. Deploy pipeline pronta in versione self-hosted.
4. Secret richiesto per il runtime: `RUNTIME_ENV_FILE`.
5. Runner self-hosted da configurare/tenere online sul portatile.
6. Mobile connesso al backend reale: `analyze`, `test`, `build apk --debug` e `build apk --release` verdi in locale.
7. Priorita prodotto aggiornata: prima consegna utile = APK scaricabile direttamente da GitHub Releases.
8. `applicationId` Android impostato a `com.carlobonvicini.workhours`.
9. Il rilascio va comunque validato anche via GitHub Actions per confermare il workflow `Mobile Release`.
10. Per update Android affidabili serve una chiave release stabile: il workflow supporta secret signing dedicati ma, se assenti, ricade sulla debug key.
11. La feed GitHub `releases/latest` risponde `404` senza autenticazione al 19 marzo 2026, quindi il controllo automatico richiede feed pubblica alternativa o repository pubblico.
12. Il percorso consigliato d ora in poi e usare il backend Linux come feed update pubblica e GitHub Releases solo come staging/build source.

## Next step immediati

1. Configurare i secret Android per firma release stabile:
   - `ANDROID_KEYSTORE_BASE64`
   - `ANDROID_KEY_ALIAS`
   - `ANDROID_KEYSTORE_PASSWORD`
   - `ANDROID_KEY_PASSWORD`
2. Configurare il canale update produzione:
   - secret `MOBILE_API_BASE_URL`
   - secret `MOBILE_UPDATE_BASE_URL`
   - env server `MOBILE_UPDATES_PUBLIC_BASE_URL`
3. Estendere il client Flutter a ferie e permessi.
4. Aggiungere un flusso piu completo di dashboard/storico sopra i dati gia letti dal backend.
5. Configurare il runner in GitHub:
   - `Settings > Actions > Runners > New self-hosted runner`
6. Inserire il secret repository:
   - `RUNTIME_ENV_FILE`
7. Fare un push di test su `main`.
8. Verificare workflow `Backend CD` verde e container `api` in `Up`.
