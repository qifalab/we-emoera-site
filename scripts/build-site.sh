#!/usr/bin/env bash
# Assemble the publishable site into dist/. This site has no build step: the
# "build" is simply excluding repository metadata from the payload.
#
# The payload is the whole document root. The old submission endpoint
# (upload.html, process.php, check_time.php) was retired on 2026-07-29, so the
# server no longer injects anything into a release; see docs/deploy.md.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

OUT="${1:-dist}"
rm -rf -- "$OUT"
mkdir -p "$OUT"

rsync -a \
  --exclude '.git/' \
  --exclude '.github/' \
  --exclude 'docs/' \
  --exclude 'scripts/' \
  --exclude 'README.md' \
  --exclude '.gitignore' \
  --exclude ".DS_Store" \
  --exclude "$OUT/" \
  ./ "$OUT/"

[ -f "$OUT/index.html" ] || { echo "assembly produced no index.html" >&2; exit 1; }
printf 'assembled %s files into %s\n' "$(find "$OUT" -type f | wc -l | tr -d ' ')" "$OUT"
