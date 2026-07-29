#!/usr/bin/env bash
# Structural checks for a hand-written static site. There is no build step and
# no framework here, so instead of a linter this asserts the things that
# actually break in practice: missing files, broken local references, and
# server-side code or credentials sneaking into the repository.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

fail=0
err() { printf 'FAIL  %s\n' "$1" >&2; fail=1; }
ok()  { printf 'ok    %s\n' "$1"; }

# ---------------------------------------------------------------- required ----
for f in index.html main.css LICENSE; do
  if [ -f "$f" ]; then ok "present: $f"; else err "missing required file: $f"; fi
done

# ------------------------------------------------------------ no backend ------
# The member-submission endpoint was retired on 2026-07-29 and the origin now
# answers 410 for anything PHP-shaped. Committing it back would be a silent
# attempt to revive an endpoint with a hardcoded credential and a stored XSS, so
# reject it here rather than at deploy time.
found_php="$(git ls-files '*.php' '*.php[0-9]' '*.phtml' '*.phar' '*.phps' '*.pht' 'upload.html' | head -5)"
if [ -n "$found_php" ]; then
  err "retired submission endpoint committed: $(echo "$found_php" | tr '\n' ' ')"
else
  ok 'no server-side code or retired upload form committed'
fi

# ------------------------------------------------------------- no secrets -----
if git ls-files -z | xargs -0 grep -lniE \
     'BEGIN [A-Z ]*PRIVATE KEY|(auth_?code|password|passwd|secret|api[_-]?key)[[:space:]]*=[[:space:]]*.[A-Za-z0-9!@#$%^&*_+-]{8,}' \
     2>/dev/null | grep -v '^scripts/' | head -5 > /tmp/.secret_hits; then
  err "possible credential in: $(tr '\n' ' ' </tmp/.secret_hits)"
else
  ok 'no credential-looking literals'
fi
rm -f /tmp/.secret_hits

# --------------------------------------------------- local references exist ---
# Pull src="..." / href="..." / url(...) out of the HTML and CSS and confirm
# every site-local target is actually in the repository.
missing=0
while IFS= read -r ref; do
  [ -n "$ref" ] || continue
  case "$ref" in
    http*|//*|data:|data:*|mailto:*|tel:*|javascript:*|'#'*|'') continue ;;
  esac
  path="${ref%%\?*}"; path="${path%%#*}"
  path="${path#/}"
  [ -n "$path" ] || continue
  # Directory references resolve to their index document.
  case "$path" in */) path="${path}index.html" ;; esac
  if [ ! -e "$path" ]; then
    err "referenced but missing: $path"; missing=$((missing + 1))
  fi
done < <(
  git ls-files '*.html' '*.css' | while read -r f; do
    grep -ohE '(src|href)="[^"]+"' "$f" 2>/dev/null | sed -E 's/^[a-z]+="//; s/"$//'
    grep -ohE 'url\((["'"'"']?)[^)"'"'"']+\1\)' "$f" 2>/dev/null | sed -E 's/^url\(["'"'"']?//; s/["'"'"']?\)$//'
  done | sort -u
)
[ "$missing" -eq 0 ] && ok 'all local references resolve'

# ---------------------------------------------------------------- summary -----
if [ "$fail" -ne 0 ]; then
  echo 'site checks failed' >&2
  exit 1
fi
echo 'site checks passed'
