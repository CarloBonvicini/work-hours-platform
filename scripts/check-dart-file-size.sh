#!/usr/bin/env bash
# Applica al mobile la soglia di 400 righe per file, sui soli file toccati.
#
# Il backend ha lo stesso limite via lint (backend/eslint.config.js). Dart non
# offre un equivalente, quindi qui si guarda il diff: i file nuovi devono nascere
# sotto soglia, quelli gia' oversize non devono crescere. I file che non tocchi
# non vengono mai segnalati: il debito esistente si riduce quando ci si lavora,
# non con una lista di eccezioni da mantenere a mano.
#
# Uso: scripts/check-dart-file-size.sh [base-ref]   (default: origin/main)

set -euo pipefail

BASE_REF="${1:-origin/main}"
MAX_LINES="${MAX_DART_FILE_LINES:-400}"

# Righe di codice: vuote e commenti esclusi, come skipBlankLines/skipComments
# della regola max-lines usata sul backend.
count_code_lines() {
  awk '
    BEGIN { in_block = 0; total = 0 }
    {
      line = $0
      gsub(/\/\*[^*]*\*+([^\/*][^*]*\*+)*\//, "", line)
      if (in_block) {
        if (line ~ /\*\//) { sub(/^.*\*\//, "", line); in_block = 0 }
        else { next }
      }
      if (line ~ /\/\*/) { sub(/\/\*.*$/, "", line); in_block = 1 }
      gsub(/^[ \t]+|[ \t]+$/, "", line)
      if (line == "") { next }
      if (line ~ /^\/\//) { next }
      total++
    }
    END { print total }
  '
}

if ! git rev-parse --verify --quiet "$BASE_REF" >/dev/null; then
  echo "Base ref '$BASE_REF' non trovata: salto il controllo dimensioni." >&2
  exit 0
fi

BASE_SHA="$(git merge-base "$BASE_REF" HEAD)"

# Diff contro l'albero di lavoro, non contro HEAD: in CI coincidono, in locale
# cosi' il controllo vede anche cio' che non e' ancora committato.
tracked="$(git diff --name-only --diff-filter=AM "$BASE_SHA" -- mobile || true)"
untracked="$(git ls-files --others --exclude-standard -- mobile || true)"
changed_files="$(printf '%s\n%s\n' "$tracked" "$untracked" | grep -E '\.dart$' | sort -u || true)"

if [ -z "$changed_files" ]; then
  echo "Nessun file Dart toccato: niente da controllare."
  exit 0
fi

failures=0

while IFS= read -r file; do
  [ -n "$file" ] || continue
  [ -f "$file" ] || continue

  current="$(count_code_lines <"$file")"
  if [ "$current" -le "$MAX_LINES" ]; then
    continue
  fi

  if previous_content="$(git show "$BASE_SHA:$file" 2>/dev/null)"; then
    previous="$(printf '%s\n' "$previous_content" | count_code_lines)"
    if [ "$current" -le "$previous" ]; then
      echo "ok (non peggiorato)  $file: $previous -> $current righe"
      continue
    fi
    echo "KO  $file: era gia' oltre le $MAX_LINES righe ed e' cresciuto ($previous -> $current)." >&2
  else
    echo "KO  $file: file nuovo con $current righe, oltre il limite di $MAX_LINES." >&2
  fi

  failures=$((failures + 1))
done <<EOF
$changed_files
EOF

if [ "$failures" -gt 0 ]; then
  cat >&2 <<'MSG'

Vedi "Soglie di dimensione" in AGENTS.md: si splitta per responsabilita, non per
far scendere un contatore. Se il file ha una responsabilita' sola e non si puo'
ridurre, spiegalo nel task invece di aggirare il controllo.
MSG
  exit 1
fi

echo "Dimensioni dei file Dart toccati: ok."
