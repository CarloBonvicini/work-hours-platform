# Auto Deploy Setup (Self-hosted Runner, No SSH)

Questa configurazione implementa questo flusso:

1. Push su `main`.
2. GitHub Actions builda l'immagine backend su runner GitHub-hosted.
3. Job di deploy gira sul tuo portatile (self-hosted runner), fa pull immagine e aggiorna i container.

Non servono `DEPLOY_HOST`, `DEPLOY_USER`, `DEPLOY_SSH_KEY`, `DEPLOY_PATH`.

## Requisiti sul portatile runner

1. Docker installato.
2. Docker Compose disponibile (`docker compose` o `docker-compose`).
3. Runner GitHub self-hosted installato come servizio.
4. Utente del runner con permessi Docker.

## Step 1 - Registra il self-hosted runner

Nel repository GitHub:

1. `Settings`
2. `Actions`
3. `Runners`
4. `New self-hosted runner`
5. Scegli Linux (se il portatile usa Linux) e segui i comandi mostrati da GitHub.

Verifica finale: il runner deve apparire `Idle` (online).

## Step 2 - Crea il secret runtime

Nel repository GitHub:

1. `Settings`
2. `Secrets and variables`
3. `Actions`
4. `New repository secret`

Nome:

```text
RUNTIME_ENV_FILE
```

Valore (multi-line, esempio):

```dotenv
COMPOSE_PROJECT_NAME=work-hours-platform
HOST=0.0.0.0
PORT=8080
API_IMAGE=ghcr.io/carlobonvicini/work-hours-api:latest
APP_DOMAIN=workhours.developerdomain.org
MOBILE_UPDATES_PUBLIC_BASE_URL=https://workhours.developerdomain.org
DATA_PROVIDER=memory
```

Per modalita scalabile con PostgreSQL:

```dotenv
COMPOSE_PROJECT_NAME=work-hours-platform
HOST=0.0.0.0
PORT=8080
API_IMAGE=ghcr.io/carlobonvicini/work-hours-api:latest
APP_DOMAIN=workhours.developerdomain.org
MOBILE_UPDATES_PUBLIC_BASE_URL=https://workhours.developerdomain.org
DATA_PROVIDER=postgres
DATABASE_URL=postgres://<user>:<password>@<host>:5432/<database>
```

## Step 3 - Cosa fa il workflow `Backend CD`

Ad ogni push su `main`:

1. Build e push immagine su GHCR (`latest` + `sha-<commit>`).
2. Job `deploy` sul self-hosted runner.
3. Scrive `infra/.env` dal secret `RUNTIME_ENV_FILE`.
4. Forza `API_IMAGE` a `ghcr.io/carlobonvicini/work-hours-api:latest`.
5. Esegue:
   - `docker compose pull` (oppure `docker-compose pull`)
   - `docker compose up -d --remove-orphans`
   - `docker image prune -f`

Se `APP_DOMAIN` e valorizzato, il deploy include anche `docker-compose.public.yml` e avvia `Caddy`, che:

1. ascolta su `80/443`
2. ottiene automaticamente il certificato HTTPS
3. pubblica il backend su `https://workhours.developerdomain.org`
4. espone anche il canale update app sotto lo stesso host

## Update mobile in produzione

La directory `infra/updates/` viene montata nel container backend come `/app/updates`.

Il workflow `Mobile Release` puo pubblicare automaticamente li:

1. l APK in `infra/updates/downloads/`
2. il metadata `infra/updates/latest-release.json`

Il backend espone poi:

- `/mobile-updates/latest.json`
- `/mobile-updates/releases/latest`
- `/mobile-updates/downloads/<apk>`

## Verifica rapida

Prerequisito DNS:

1. Crea un record `A`:
   - `workhours.developerdomain.org` -> IP pubblico del server Linux
2. Assicurati che sul server siano aperte le porte `80` e `443`.

Poi:

1. Fai un push su `main`.
2. In GitHub `Actions`, verifica workflow `Backend CD` verde.
3. Sul portatile runner:

```bash
cd <workspace-runner>/<repo>/infra
docker compose ps
docker compose logs -f api
```

Se usi `docker-compose` v1, sostituisci i comandi.

## Note importanti

1. Puoi pushare da qualsiasi PC: il deploy parte comunque, perche triggerato da GitHub.
2. Il portatile runner deve essere acceso e online.
3. Niente SSH nel deploy pipeline.
4. Con `APP_DOMAIN=workhours.developerdomain.org` la URL pubblica corretta diventa `https://workhours.developerdomain.org`, mentre `127.0.0.1:8080` resta solo un bind locale del server.
