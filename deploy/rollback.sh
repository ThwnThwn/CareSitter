#!/bin/sh
# Roll the API and admin web back to an earlier release without touching the DB.
#
#   sh deploy/rollback.sh            # back to deploy/.releases/previous
#   sh deploy/rollback.sh <sha>      # back to a specific earlier release
#
# Uses the release image kept by deploy.sh when present, otherwise rebuilds it
# from that commit. Migrations are forward-only: the older code must tolerate
# the newer schema. If it cannot, restore the pre-deploy backup instead
# (see plan/deploy/PRODUCTION_RUNBOOK.md, "Khôi phục database").
set -eu
repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
. "$repo_dir/deploy/ops/common.sh"
cd "$repo_dir"
for command in git docker curl; do require_command "$command"; done

target=${1:-$(cat "$releases_dir/previous" 2>/dev/null || true)}
[ -n "$target" ] || fail 'No previous release recorded; pass a commit sha.'
current=$(cat "$releases_dir/current" 2>/dev/null || true)

lock_dir="$releases_dir/lock"
mkdir "$lock_dir" 2>/dev/null || fail "Another deployment holds $lock_dir."
trap 'rmdir "$lock_dir" 2>/dev/null || true' EXIT
trap 'exit 1' HUP INT TERM

git fetch --quiet --prune origin || log 'WARNING: fetch failed; using local objects.'
sha=$(git rev-parse --verify --quiet "$target^{commit}") || fail "Unknown commit: $target"
RELEASE_TAG=$(printf '%s' "$sha" | cut -c1-12)
export RELEASE_TAG
load_ops_env

git -c advice.detachedHead=false checkout --quiet --detach "$sha"
if docker image inspect "caresitter-api:$RELEASE_TAG" >/dev/null 2>&1 &&
    docker image inspect "caresitter-admin:$RELEASE_TAG" >/dev/null 2>&1; then
    log "Reusing kept images for $RELEASE_TAG"
else
    log "Images for $RELEASE_TAG are gone; rebuilding from that commit"
    app_compose build api admin
fi

app_compose up -d --no-build api admin proxy
if ! wait_for_ready 40; then
    send_alert "Manual rollback to $RELEASE_TAG is unhealthy. Check: sh deploy/app-compose.sh logs api"
    fail "Rollback target $RELEASE_TAG did not become healthy."
fi

printf '%s\n' "$sha" > "$releases_dir/current"
[ -z "$current" ] || printf '%s\n' "$current" > "$releases_dir/previous"
printf '%s rollback %s -> %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "${current:-unknown}" "$sha" >> "$releases_dir/history.log"
send_alert "Rolled back to $RELEASE_TAG (was ${current:-unknown})."
log "Rollback to $RELEASE_TAG is healthy."
