#!/usr/bin/env sh
set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
REPO_DIR="$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)"

# One-command deploy: aggiorna codice + immagini + container.
if [ -d "$REPO_DIR/.git" ]; then
  git -C "$REPO_DIR" fetch origin main
  git -C "$REPO_DIR" checkout main
  git -C "$REPO_DIR" pull --ff-only origin main
fi

cd "$SCRIPT_DIR"

compose() {
  if docker compose version >/dev/null 2>&1; then
    docker compose "$@"
  elif command -v docker-compose >/dev/null 2>&1; then
    docker-compose "$@"
  else
    echo "Docker Compose non trovato. Installa docker compose plugin o docker-compose." >&2
    exit 1
  fi
}

set -- -f docker-compose.yml
app_domain="$(grep '^APP_DOMAIN=' .env 2>/dev/null | cut -d= -f2- || true)"
if [ -n "$app_domain" ]; then
  set -- "$@" -f docker-compose.public.yml
fi

compose "$@" pull
compose "$@" up -d --remove-orphans
docker image prune -f
