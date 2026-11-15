#!/bin/sh
# Deploy one commit to this VM (repository checkout at e.g. /opt/caresitter).
#
#   sh deploy/deploy.sh <commit-sha | origin/main | tag>
#
# Order: fetch → checkout → preflight → build images (nothing live changes if
# this fails) → encrypted pre-deploy DB backup → migrate → start → health gate.
# If the health gate fails, the API/admin images of the previous release are
# started again. SQL migrations are forward-only and are NOT reverted: restore
# the printed pre-deploy backup only if the new schema itself is the problem.
set -eu
repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
. "$repo_dir/deploy/ops/common.sh"
cd "$repo_dir"

target=${1:?Usage: sh deploy/deploy.sh <commit-sha|ref>}
for command in git docker curl age sha256sum; do require_command "$command"; done
mkdir -p "$releases_dir"

# --- Stage 1: lock, resolve and check out the target, then re-exec its own deploy.sh.
if [ "${CARESITTER_DEPLOY_STAGE:-1}" = 1 ]; then
    lock_dir="$releases_dir/lock"
    mkdir "$lock_dir" 2>/dev/null || fail "Another deployment holds $lock_dir (remove it only if no deploy is running)."
    trap 'rmdir "$lock_dir" 2>/dev/null || true' EXIT
    trap 'exit 1' HUP INT TERM

    [ -z "$(git status --porcelain --untracked-files=no)" ] ||
        fail 'Tracked files were edited on the VM. Commit them upstream or discard them before deploying.'
    git fetch --quiet --prune --tags origin
    sha=$(git rev-parse --verify --quiet "$target^{commit}") || fail "Unknown commit or ref: $target"
    previous=$(cat "$releases_dir/current" 2>/dev/null || true)
    log "Deploying $sha (previous: ${previous:-none})"
    git -c advice.detachedHead=false checkout --quiet --detach "$sha"
    # Run the target commit's own deploy logic, keeping this process's lock.
    CARESITTER_DEPLOY_STAGE=2 CARESITTER_PREVIOUS_RELEASE="$previous" CARESITTER_DEPLOY_LOCK="$lock_dir" \
        sh "$repo_dir/deploy/deploy.sh" "$sha" && status=0 || status=$?
    exit "$status"
fi

# --- Stage 2: runs from the target commit.
sha=$target
previous=${CARESITTER_PREVIOUS_RELEASE:-}
RELEASE_TAG=$(printf '%s' "$sha" | cut -c1-12)
export RELEASE_TAG
load_ops_env

restore_previous_checkout() {
    [ -n "$previous" ] || return 0
    git -c advice.detachedHead=false checkout --quiet --detach "$previous" || true
}

sh deploy/preflight.sh deploy/.env

log "Building release images caresitter-api:$RELEASE_TAG and caresitter-admin:$RELEASE_TAG"
if ! app_compose build --pull api admin; then
    restore_previous_checkout
    fail 'Image build failed. Nothing running was changed.'
fi

app_compose up -d --wait db redis

backup_note='no backup (first deployment)'
if [ -n "$previous" ] && [ "${SKIP_PREDEPLOY_BACKUP:-false}" != true ]; then
    log 'Taking encrypted pre-deploy backup'
    if ! sh deploy/ops/backup-main.sh "predeploy-$RELEASE_TAG"; then
        restore_previous_checkout
        fail 'Pre-deploy backup failed; migration and release were not started.'
    fi
    backup_note=$(cat "$BACKUP_DIRECTORY/.last-file" 2>/dev/null || echo 'see backup directory')
fi

log 'Applying SQL migrations'
if ! app_compose run --rm migrate; then
    restore_previous_checkout
    send_alert "Deploy $RELEASE_TAG stopped: migration failed. Previous containers keep running. Pre-deploy backup: $backup_note"
    fail 'Migration failed. The previous API/admin containers are still running.'
fi

log 'Starting new release'
app_compose up -d --no-build api admin proxy

if wait_for_ready 40; then
    printf '%s\n' "$sha" > "$releases_dir/current"
    [ -z "$previous" ] || printf '%s\n' "$previous" > "$releases_dir/previous"
    printf '%s deploy %s from %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$sha" "${previous:-none}" >> "$releases_dir/history.log"
    # Keep the newest release images for fast rollback; remove older ones.
    for repo in caresitter-api caresitter-admin; do
        docker image ls "$repo" --format '{{.Tag}}' |
            grep -v -x -e "$RELEASE_TAG" -e local -e "$(printf '%s' "$previous" | cut -c1-12)" |
            tail -n "+$((KEEP_RELEASE_IMAGES + 1))" |
            while IFS= read -r old; do docker image rm "$repo:$old" >/dev/null 2>&1 || true; done
    done
    log "Release $RELEASE_TAG is healthy at $HEALTH_URL"
    exit 0
fi

log "Release $RELEASE_TAG failed its health gate"
app_compose logs --no-color --tail=80 api >&2 || true
if [ -n "$previous" ]; then
    prev_tag=$(printf '%s' "$previous" | cut -c1-12)
    restore_previous_checkout
    RELEASE_TAG=$prev_tag app_compose up -d --no-build api admin proxy || true
    if wait_for_ready 40; then
        send_alert "Deploy $RELEASE_TAG failed health check; rolled back to $prev_tag. Migrations stay applied. Pre-deploy backup: $backup_note"
    else
        send_alert "Deploy $RELEASE_TAG failed AND rollback to $prev_tag is unhealthy. Manual action needed. Pre-deploy backup: $backup_note"
    fi
    printf '%s rollback-auto %s -> %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$sha" "$previous" >> "$releases_dir/history.log"
else
    send_alert "First deploy $RELEASE_TAG is unhealthy; no previous release to roll back to."
fi
exit 1
