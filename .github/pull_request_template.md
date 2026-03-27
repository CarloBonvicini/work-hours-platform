## Summary
- What changed:
- Why:

## Scope
- [ ] Backend
- [ ] Mobile
- [ ] Infra/CI

## Architecture check
- [ ] I kept responsibilities separated (UI/orchestration/domain/persistence).
- [ ] I avoided adding logic to oversized legacy files when a dedicated module was better.
- [ ] If I touched a legacy monolith, I kept changes minimal and documented follow-up refactor.

## Quality gates
- [ ] `backend`: `npm run lint`
- [ ] `backend`: `npm test`
- [ ] `backend`: `npm run build`
- [ ] `mobile`: `flutter analyze` (if touched)
- [ ] `mobile`: `flutter test` (if touched)

## Tests
- Added/updated tests:
- Coverage of critical paths and error paths:

## Risk and rollout
- Known risks:
- Mitigation/rollback:
