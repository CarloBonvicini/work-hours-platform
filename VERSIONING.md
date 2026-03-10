# Versioning Automatico

## Stato attuale

Versioning automatico temporaneamente disattivato nel workflow CD per stabilizzare il deploy.
Appena il deploy torna verde in modo stabile, si riattiva la logica `patch/minor/major`.

## Regola

Partiamo da `v0.0.0`.

Ad ogni push su `main`, il workflow `Backend CD` crea automaticamente il prossimo tag semantico:

1. Push normale: incrementa patch
   - `v0.0.0` -> `v0.0.1` -> `v0.0.2`
2. Push con `RELEASE` nel commit message: incrementa minor
   - `v0.0.9` -> `v0.1.0`
3. Push con `RELEASE+` nel commit message: incrementa major
   - `v0.9.9` -> `v1.0.0`

## Priorita marker

Se nel messaggio e presente `RELEASE+`, ha priorita su `RELEASE`.

Ordine applicato:

1. `RELEASE+` -> major
2. `RELEASE` -> minor
3. default -> patch

## Esempi commit message

1. `feat: aggiunta report mensile` -> patch
2. `feat: nuova dashboard RELEASE` -> minor
3. `feat: riscrittura dominio ore RELEASE+` -> major

## Output usato nel deploy

Il tag versione viene usato anche per l immagine Docker:

1. `latest`
2. `vX.Y.Z`
3. `sha-<commit>`

## Nota importante

La decisione major/minor/patch viene calcolata dal messaggio dell ultimo commit del push (`head commit`).
