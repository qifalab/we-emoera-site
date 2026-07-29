#!/usr/bin/env bash
# Publish, list or roll back a release on the origin server.
#
# This script is intentionally identical in every site repository that deploys
# to the shared site-deploy mechanism; only the DEPLOY_* values differ. Keep the
# copies in sync when changing it.
#
# The server side accepts nothing but the verbs below: the SSH key is pinned to
# a forced command, so this script cannot run arbitrary commands even if its
# secrets leak.
#
# Required environment:
#   DEPLOY_SITE          site name as registered in site-deploy.conf
#   DEPLOY_HOST          origin host
#   DEPLOY_USER          unprivileged deploy account
#   DEPLOY_SSH_KEY       private key, PEM text
#   DEPLOY_KNOWN_HOSTS   host public key line(s) for strict verification
# Required for `publish`:
#   DEPLOY_DIST          directory whose contents become the release
# Optional, for the post-activation check. Requests always go to DEPLOY_HOST
# directly so that the origin is verified rather than any CDN in front of it:
#   DEPLOY_VERIFY_HOST    site hostname sent as Host header / SNI
#   DEPLOY_VERIFY_SCHEME  http (default) or https
#   DEPLOY_VERIFY_PATHS   extra space-separated paths that must return 200,
#                         for sites whose assets are not content-hashed

set -euo pipefail

: "${DEPLOY_SITE:?DEPLOY_SITE is required}"
: "${DEPLOY_HOST:?DEPLOY_HOST is required}"
: "${DEPLOY_USER:?DEPLOY_USER is required}"
: "${DEPLOY_SSH_KEY:?DEPLOY_SSH_KEY is required}"
: "${DEPLOY_KNOWN_HOSTS:?DEPLOY_KNOWN_HOSTS is required}"

WORK="$(mktemp -d)"
cleanup() { rm -rf -- "$WORK"; }
trap cleanup EXIT

KEY="$WORK/id"
KNOWN="$WORK/known_hosts"
umask 077
printf '%s\n' "$DEPLOY_SSH_KEY" >"$KEY"
printf '%s\n' "$DEPLOY_KNOWN_HOSTS" >"$KNOWN"
chmod 600 "$KEY" "$KNOWN"
umask 022

remote() {
  ssh -i "$KEY" -o IdentitiesOnly=yes \
      -o StrictHostKeyChecking=yes -o UserKnownHostsFile="$KNOWN" \
      -o BatchMode=yes -o PasswordAuthentication=no \
      -o ConnectTimeout=20 -o ServerAliveInterval=15 \
      -o LogLevel=ERROR \
      "$DEPLOY_USER@$DEPLOY_HOST" "$@"
}

# Fetch <path> straight from the origin, bypassing any CDN.
origin_code() {
  local path="$1" host="${DEPLOY_VERIFY_HOST:-}" scheme="${DEPLOY_VERIFY_SCHEME:-http}"
  local args=(-sS -o /dev/null -m 30 --retry 3 --retry-delay 3 --retry-all-errors -w '%{http_code}')
  if [ "$scheme" = "https" ]; then
    args+=(-k --resolve "$host:443:$DEPLOY_HOST")
    curl "${args[@]}" "https://$host$path"
  else
    args+=(-H "Host: $host")
    curl "${args[@]}" "http://$DEPLOY_HOST$path"
  fi
}

verify_origin() {
  local code
  [ -n "${DEPLOY_VERIFY_HOST:-}" ] || { echo 'no DEPLOY_VERIFY_HOST set, skipping origin check'; return 0; }
  code="$(origin_code /)"
  [ "$code" = "200" ] || { echo "origin returned HTTP $code for /" >&2; return 1; }
  echo "origin check: HTTP 200 for /"
}

# Prove the bytes we just built are the ones being served, not a stale release.
# Content-hashed bundles are discovered from index.html; sites without hashing
# declare a few representative paths through DEPLOY_VERIFY_PATHS instead.
verify_assets() {
  local asset code checked=0
  [ -n "${DEPLOY_VERIFY_HOST:-}" ] || return 0
  [ -f "${DEPLOY_DIST:-}/index.html" ] || return 0
  while read -r asset; do
    [ -n "$asset" ] || continue
    code="$(origin_code "$asset")"
    [ "$code" = "200" ] || { echo "origin missing freshly built asset $asset (HTTP $code)" >&2; return 1; }
    echo "origin check: HTTP 200 for $asset"
    checked=$((checked + 1))
  done < <(
    # `|| true`: a site without content-hashed bundles has no matches here, and
    # errexit would otherwise abort this subshell before the paths below run.
    { grep -oE '/(assets|static)/[A-Za-z0-9._-]+' "$DEPLOY_DIST/index.html" || true; } | sort -u | head -5
    printf '%s\n' ${DEPLOY_VERIFY_PATHS:-}
  )
  echo "verified $checked asset path(s) on the origin"
}

cmd_publish() {
  local version="$1" payload="$WORK/payload.tgz" active
  : "${DEPLOY_DIST:?DEPLOY_DIST is required for publish}"
  [ -d "$DEPLOY_DIST" ] || { echo "DEPLOY_DIST is not a directory: $DEPLOY_DIST" >&2; exit 1; }
  [ -f "$DEPLOY_DIST/index.html" ] || { echo "no index.html in $DEPLOY_DIST" >&2; exit 1; }

  # Symlinks are rejected by the server, so dereference them here. GNU tar also
  # gets flags that normalise entry order and ownership; bsdtar on macOS has no
  # equivalents, so local runs simply skip them. Modification times are left
  # alone so that Last-Modified and ETag on the origin stay meaningful.
  local tar_opts=(--dereference)
  if tar --version 2>/dev/null | grep -q 'GNU tar'; then
    tar_opts+=(--format=gnu --sort=name --owner=0 --group=0 --numeric-owner)
  fi
  tar "${tar_opts[@]}" -czf "$payload" -C "$DEPLOY_DIST" .
  echo "payload: $(stat -f%z "$payload" 2>/dev/null || stat -c%s "$payload") bytes"

  echo "publishing $DEPLOY_SITE/$version"
  remote "publish $DEPLOY_SITE $version" <"$payload"

  active="$(remote "current $DEPLOY_SITE")"
  [ "$active" = "$version" ] || { echo "activation mismatch: server reports '$active'" >&2; exit 1; }
  echo "active release: $active"
  verify_origin
  verify_assets
}

cmd_rollback() {
  local version="${1:-}" before after
  before="$(remote "current $DEPLOY_SITE" || echo '-')"
  if [ -n "$version" ]; then
    remote "rollback $DEPLOY_SITE $version"
  else
    remote "rollback $DEPLOY_SITE"
  fi
  after="$(remote "current $DEPLOY_SITE")"
  [ "$after" != "$before" ] || { echo "rollback did not change the active release" >&2; exit 1; }
  echo "rolled back: $before -> $after"
  verify_origin
}

case "${1:-}" in
  publish)  [ $# -eq 2 ] || { echo 'usage: deploy-release.sh publish <version>' >&2; exit 2; }
            cmd_publish "$2" ;;
  rollback) cmd_rollback "${2:-}" ;;
  list)     remote "list $DEPLOY_SITE" ;;
  current)  remote "current $DEPLOY_SITE" ;;
  *) echo 'usage: deploy-release.sh {publish <version>|rollback [version]|list|current}' >&2; exit 2 ;;
esac
