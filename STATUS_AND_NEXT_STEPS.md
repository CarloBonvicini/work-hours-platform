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

## Stato attuale (10 marzo 2026)

1. Repository GitHub privato configurato e sincronizzato.
2. Deploy pipeline pronta in versione self-hosted.
3. Secret richiesto per il runtime: `RUNTIME_ENV_FILE`.
4. Runner self-hosted da configurare/tenere online sul portatile.

## Next step immediati

1. Configurare il runner in GitHub:
   - `Settings > Actions > Runners > New self-hosted runner`
2. Inserire il secret repository:
   - `RUNTIME_ENV_FILE`
3. Fare un push di test su `main`.
4. Verificare workflow `Backend CD` verde e container `api` in `Up`.
5. Continuare Sprint mobile:
   - `flutter create .` dentro `mobile/`
   - struttura a layer (`presentation/application/domain/data`)
