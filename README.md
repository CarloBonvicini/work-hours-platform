# Work Hours Platform (Monorepo)

Monorepo iniziale con separazione logica tra:

- `mobile/` app Flutter
- `backend/` API leggera
- `infra/` deploy Docker Compose
- `.github/workflows/` pipeline CI/CD

Documenti di gestione:

- `STATUS_AND_NEXT_STEPS.md`
- `ROADMAP_COMPLETA.md`

## Perche monorepo adesso

- setup piu rapido
- pipeline separate ma coordinate
- evoluzione semplice verso due repo in futuro, se serve

## Struttura

```text
work-hours-platform/
  mobile/
  backend/
  infra/
  .github/workflows/
```

## Quick Start

### Backend

```bash
cd backend
npm install
npm run dev
```

Health endpoint:

```text
GET http://localhost:8080/health
```

### Mobile

Flutter non e incluso in questa macchina in questo momento.
Quando installi Flutter:

```bash
cd mobile
flutter create .
```

Poi organizziamo il codice in:

- `lib/presentation`
- `lib/application`
- `lib/domain`
- `lib/data`

### Deploy (server debole)

La strategia e:

1. build immagine in GitHub Actions
2. push su registry (es. GHCR)
3. server fa solo `docker compose pull` + `docker compose up -d`
