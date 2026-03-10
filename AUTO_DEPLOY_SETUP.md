# Auto Deploy Setup (Prima Pull Manuale, Poi Automatico)

Questa configurazione implementa esattamente questo flusso:

1. Prima volta: clone/pull manuale sul server.
2. Dopo: ogni push su `main` aggiorna automaticamente il server.

## Requisiti server

1. Docker + Docker Compose plugin installati.
2. Git installato.
3. Utente deploy dedicato (consigliato) con accesso Docker.
4. Accesso SSH dal workflow GitHub Actions al server.

## Step 1 - Prima configurazione manuale sul server (una sola volta)

```bash
mkdir -p /opt/work-hours-platform
cd /opt
git clone git@github.com:CarloBonvicini/work-hours-platform.git
cd /opt/work-hours-platform/infra
cp .env.example .env
```

Poi modifica `infra/.env` secondo le tue esigenze.

## Step 2 - Login GHCR sul server (una sola volta)

Per immagini private GHCR:

```bash
echo "<GHCR_PAT_READ_PACKAGES>" | docker login ghcr.io -u CarloBonvicini --password-stdin
```

## Step 3 - Configura Secrets su GitHub

Nel repository `work-hours-platform`, aggiungi questi secrets:

1. `DEPLOY_HOST` - host/IP server
2. `DEPLOY_USER` - utente SSH
3. `DEPLOY_SSH_KEY` - chiave privata SSH usata da GitHub Actions
4. `DEPLOY_PATH` - path repo sul server (es: `/opt/work-hours-platform`)

## Step 4 - Come funziona il deploy automatico

Ad ogni push su `main`, il workflow `Backend CD` esegue:

1. Build immagine backend in GitHub Actions.
2. Push su GHCR (`latest` + tag SHA).
3. SSH nel server.
4. `git pull --ff-only` nel path deploy.
5. `docker compose pull`.
6. `docker compose up -d --remove-orphans`.
7. `docker image prune -f`.

## Verifica rapida

Dopo un push su `main`:

1. Controlla tab Actions su GitHub.
2. Sul server:

```bash
cd /opt/work-hours-platform/infra
docker compose ps
docker compose logs -f api
```

## Note importanti

1. Questo modello evita build pesanti sul server.
2. Il server aggiorna solo codice e immagini.
3. Se non vuoi aggiornare codice ad ogni deploy, puoi togliere il `git pull` dal workflow.

