# Git Hooks

Per attivare i hook locali:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\setup-git-hooks.ps1
```

Il `pre-commit` esegue:
- backend: `npm run lint` + `npm test` (solo se ci sono file staged in `backend/`)
- mobile: `flutter analyze` + `flutter test` (solo se ci sono file staged in `mobile/`)
