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
COMPOSE_PROJECT_NAME=infra
HOST=0.0.0.0
PORT=8080
API_IMAGE=ghcr.io/carlobonvicini/work-hours-api:latest
APP_DOMAIN=
MOBILE_UPDATES_PUBLIC_BASE_URL=https://workhours.developerdomain.org
DATA_PROVIDER=postgres
POSTGRES_DB=workhours
POSTGRES_USER=workhours
POSTGRES_PASSWORD=change_me
DATABASE_URL=postgres://workhours:change_me@db:5432/workhours
SUPER_ADMIN_EMAIL=owner@example.com
SUPER_ADMIN_PASSWORD=change_me_long
```

Note:
1. `POSTGRES_PASSWORD` deve essere cambiata con una password reale.
2. `DATABASE_URL` deve usare la stessa password e nel setup Docker interno resta con host `db`.
3. `COMPOSE_PROJECT_NAME` resta `infra` (il deploy lo forza comunque): e il nome dello stack in produzione (`infra-api-1`, `infra-db-1`, volume `infra_postgres_data`). Un nome diverso creerebbe uno stack nuovo con un database vuoto.
4. `APP_DOMAIN` vuoto: in produzione il TLS lo fa il tunnel Cloudflare (vedi sotto), Caddy non serve.

## Step 3 - Cosa fa il workflow `Backend CD`

Ad ogni push su `main`:

1. Build e push immagine su GHCR (`latest` + `sha-<commit>`).
2. Job `deploy` sul self-hosted runner.
3. Scrive `infra/.env` dal secret `RUNTIME_ENV_FILE`.
4. Forza `API_IMAGE` a `ghcr.io/carlobonvicini/work-hours-api:latest` e `COMPOSE_PROJECT_NAME=infra`.
5. Esegue:
   - `docker compose pull`
   - rimuove qualsiasi container, anche fermo, che pubblica le porte `8080` (e `80/443` se c'e Caddy)
   - `docker compose up -d --remove-orphans`
   - `docker image prune -f`
6. Verifica `http://127.0.0.1:8080/health` sul portatile.

## Come arriva il traffico pubblico (produzione)

Sul portatile gira `cloudflared` (Cloudflare Tunnel, servizio systemd condiviso con gli altri progetti): il record DNS `workhours.developerdomain.org` e proxato da Cloudflare, il tunnel porta le richieste a `http://localhost:8080`, cioe direttamente al container `infra-api-1`. Niente porte aperte sul router, niente Caddy, niente certificati da gestire.

Quindi, se il sito risponde `502` da Cloudflare in pochi millisecondi, il tunnel e connesso ma **la porta 8080 sul portatile e chiusa**: lo stack Docker non sta girando. Un `530`/`1033` invece significa che `cloudflared` e giu.

Solo se un giorno si volesse fare a meno del tunnel: con `APP_DOMAIN` valorizzato il deploy include anche `docker-compose.public.yml` e avvia Caddy su `80/443` con certificato automatico; servono un record `A` verso l'IP pubblico e le porte aperte sul router.

## Monitoraggio

Il workflow `Backend Healthcheck` (`.github/workflows/backend-healthcheck.yml`) controlla `/health` ogni 15 minuti da un runner GitHub. Se fallisce apre una issue con label `backend-down` (mail di GitHub), al controllo successivo rilancia `Backend CD` una volta, e chiude la issue quando il backend torna. Il container `api` ha un healthcheck Docker e `autoheal` lo riavvia se resta unhealthy per ~2.5 minuti.

## Accesso al portatile

Dal PC di Carlo, solo in LAN e solo con chiave: `ssh robot` (setup in `scripts/setup-ssh-lan.sh`). Comandi utili:

```bash
docker ps -a
docker logs --tail 100 infra-api-1
docker inspect --format '{{.State.Health.Status}}' infra-api-1
```

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

1. Fai un push su `main` (o `gh workflow run "Backend CD" --ref main`).
2. In GitHub `Actions`, verifica workflow `Backend CD` verde.
3. Sul portatile runner (`ssh robot`):

```bash
cd /opt/actions-runner/_work/work-hours-platform/work-hours-platform/infra
docker compose ps
docker compose logs -f api
```

## Note importanti

1. Puoi pushare da qualsiasi PC: il deploy parte comunque, perche triggerato da GitHub.
2. Il portatile runner deve essere acceso e online.
3. Niente SSH nel deploy pipeline.
4. La URL pubblica e `https://workhours.developerdomain.org` (via tunnel Cloudflare); `127.0.0.1:8080` e il bind locale sul portatile.
5. Non lasciare in giro container di vecchi progetti compose con `restart: unless-stopped` sulle stesse porte: nel 2026 un residuo del primo setup (`work-hours-platform_api_1`) ha tenuto giu il backend per 47 giorni contendendo la porta 8080 all'api vera dopo un riavvio.
