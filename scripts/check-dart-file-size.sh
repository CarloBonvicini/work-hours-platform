#!/usr/bin/env bash
# Controlli strutturali sul mobile, applicati ai soli file toccati dal diff:
# la soglia di 400 righe per file e il divieto di nuovi file sciolti nella
# radice di lib/presentation/home/.
#
# Il backend ha lo stesso limite via lint (backend/eslint.config.js). Dart non
# offre un equivalente, quindi qui si guarda il diff: i file nuovi devono nascere
# sotto soglia, e i file gia' oversize non devono crescere *nel complesso*. I
# file che non tocchi non vengono mai segnalati: il debito esistente si riduce
# quando ci si lavora, non con una lista di eccezioni da mantenere a mano.
#
# Il bilancio e' sul diff intero, non file per file: estrarre un modulo nuovo
# costa sempre qualche riga di registrazione a chi lo richiama (una `part`, un
# mixin, una firma condivisa), e contarle come peggioramento spingerebbe a fare
# l'opposto di quel che serve, cioe' lasciare tutto nel monolite. Quello che
# conta e' che il totale delle righe nei file oversize scenda.
#
# Uso: scripts/check-dart-file-size.sh [base-ref]   (default: origin/main)

set -euo pipefail

BASE_REF="${1:-origin/main}"
MAX_LINES="${MAX_DART_FILE_LINES:-400}"
HOME_DIR="mobile/lib/presentation/home"

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
oversize_delta=0
oversize_report=""

while IFS= read -r file; do
  [ -n "$file" ] || continue
  [ -f "$file" ] || continue

  is_new=0
  if ! git cat-file -e "$BASE_SHA:$file" 2>/dev/null; then
    is_new=1
  fi

  # La radice di home/ e' la regia, non un contenitore: il codice nuovo va in
  # logic/, models/, home_state/ o widgets/<area>/.
  if [ "$is_new" -eq 1 ] && [ "$file" != "$HOME_DIR/home_screen.dart" ]; then
    case "$file" in
      "$HOME_DIR"/*)
        # `*` nel case copre anche le `/`: il nome sciolto e' quello che dopo
        # il prefisso non contiene altre cartelle.
        leaf="${file#"$HOME_DIR/"}"
        case "$leaf" in
          */*) ;;
          *)
            echo "KO  $file: file nuovo nella radice di home/. Mettilo in logic/, models/, home_state/ o widgets/<area>/." >&2
            failures=$((failures + 1))
            ;;
        esac
        ;;
    esac
  fi

  current="$(count_code_lines <"$file")"
  if [ "$current" -le "$MAX_LINES" ]; then
    continue
  fi

  if [ "$is_new" -eq 0 ] && previous_content="$(git show "$BASE_SHA:$file" 2>/dev/null)"; then
    previous="$(printf '%s\n' "$previous_content" | count_code_lines)"
    delta=$((current - previous))
    oversize_delta=$((oversize_delta + delta))
    if [ "$delta" -le 0 ]; then
      oversize_report="${oversize_report}  $file: $previous -> $current righe ($delta)
"
    else
      oversize_report="${oversize_report}  $file: $previous -> $current righe (+$delta)
"
    fi
    continue
  fi

  echo "KO  $file: file nuovo con $current righe, oltre il limite di $MAX_LINES." >&2
  failures=$((failures + 1))
done <<EOF
$changed_files
EOF

if [ -n "$oversize_report" ]; then
  echo "File gia' oltre le $MAX_LINES righe toccati dal diff:"
  printf '%s' "$oversize_report"
  if [ "$oversize_delta" -gt 0 ]; then
    echo "KO  nel complesso sono cresciuti di $oversize_delta righe." >&2
    failures=$((failures + 1))
  else
    echo "ok  bilancio complessivo: $oversize_delta righe."
  fi
fi

if [ "$failures" -gt 0 ]; then
  cat >&2 <<'MSG'

Vedi "Soglie di dimensione" in AGENTS.md: si splitta per responsabilita, non per
far scendere un contatore. Il bilancio e' sul diff intero: se un file oversize
cresce, compensa estraendo davvero da un altro, non limando righe. Se non si
puo' ridurre, spiegalo nel task invece di aggirare il controllo.
MSG
  exit 1
fi

echo "Dimensioni dei file Dart toccati: ok."
