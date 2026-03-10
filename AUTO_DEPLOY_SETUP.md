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
DATA_PROVIDER=memory
```

Per modalita scalabile con PostgreSQL:

```dotenv
COMPOSE_PROJECT_NAME=work-hours-platform
HOST=0.0.0.0
PORT=8080
API_IMAGE=ghcr.io/carlobonvicini/work-hours-api:latest
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

## Verifica rapida

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
