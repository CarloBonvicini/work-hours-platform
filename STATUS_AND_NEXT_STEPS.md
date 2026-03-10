# Cosa Abbiamo Fatto E Next Step

## Cosa abbiamo fatto

1. Abbiamo creato un monorepo in `work-hours-platform` con separazione chiara:
   - `mobile/`
   - `backend/`
   - `infra/`
   - `.github/workflows/`
2. Abbiamo impostato un backend base in Node + Fastify con endpoint health:
   - `GET /health`
3. Abbiamo aggiunto test automatici backend (Vitest) e build TypeScript.
4. Abbiamo preparato containerizzazione backend:
   - `backend/Dockerfile`
   - healthcheck nel container
5. Abbiamo preparato infrastruttura deploy:
   - `infra/docker-compose.yml`
   - `infra/deploy.sh`
6. Abbiamo creato workflow GitHub Actions:
   - `backend-ci.yml` (test + build backend)
   - `mobile-ci.yml` (analyze + test Flutter, quando esiste `pubspec.yaml`)
   - `backend-cd.yml` (build/push immagine + deploy via SSH)
7. Abbiamo inizializzato Git locale e creato commit iniziale su branch `main`.

## Stato attuale

- Backend locale: pronto e testato.
- Pipeline: definite nei workflow.
- Mobile: cartella pronta, ma Flutter va ancora installato su questa macchina.
- Remoto GitHub: da creare (repo private) e collegare al repo locale.

## Next step immediati

1. Creare un repository GitHub private vuoto.
2. Collegare remote e push:
   - `git remote add origin <URL_REPO_PRIVATE>`
   - `git push -u origin main`
3. Configurare GitHub Secrets per deploy:
   - `DEPLOY_HOST`
   - `DEPLOY_USER`
   - `DEPLOY_SSH_KEY`
   - `DEPLOY_PATH`
4. Installare Flutter localmente e inizializzare `mobile/`:
   - `cd mobile`
   - `flutter create .`
5. Avviare Sprint 1 tecnico:
   - modellazione dati v1
   - primi endpoint reali (`Profile`, `WorkEntry`, `LeaveEntry`)
   - prime schermate Flutter (onboarding, profilo, inserimento ore)

## Definizione di pronto (primo traguardo)

Consideriamo il setup base completato quando:

1. Il push su repository private e avvenuto.
2. CI backend passa su GitHub.
3. `GET /health` risponde in locale e in ambiente deploy.
4. Mobile Flutter e inizializzato con struttura a layer.
