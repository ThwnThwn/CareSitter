#!/bin/sh
# Encrypted logical backup of the main CareSitter database.
#
#   sh deploy/ops/backup-main.sh [label]     # label: scheduled (default), predeploy-<tag>, manual
#
# The dump is encrypted with `age` to a PUBLIC recipient key; the private key
# must NOT live on this VM (keep it in the team password manager / offline).
# Optional off-host copy via rclone when BACKUP_RCLONE_REMOTE is set.
# Configure in deploy/ops.env (see deploy/ops.env.example).
set -eu
repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
. "$repo_dir/deploy/ops/common.sh"
for command in docker age sha256sum; do require_command "$command"; done
load_ops_env

label=$(printf '%s' "${1:-scheduled}" | tr -c 'a-zA-Z0-9_.-' '-')
recipient=${BACKUP_RECIPIENT_FILE:?Set BACKUP_RECIPIENT_FILE in deploy/ops.env}
[ -s "$recipient" ] || fail "Backup recipient file is missing or empty: $recipient"
mkdir -p "$BACKUP_DIRECTORY"
chmod 700 "$BACKUP_DIRECTORY"

stamp=$(date -u +%Y%m%dT%H%M%SZ)
name="main-$stamp-$label.dump.age"
partial="$BACKUP_DIRECTORY/$name.partial"
container_dump="/tmp/caresitter-backup-$stamp.dump"
status_file=$(mktemp)
cleanup() {
    rm -f -- "$partial" "$status_file"
    app_compose exec -T db rm -f "$container_dump" >/dev/null 2>&1 || true
}
trap cleanup EXIT
trap 'exit 1' HUP INT TERM

# Dump inside the DB container and validate the archive before it leaves.
app_compose exec -T db sh -ec "umask 077
pg_dump --format=custom --no-owner -U \"\$POSTGRES_USER\" -d \"\$POSTGRES_DB\" -f '$container_dump'
pg_restore --list '$container_dump' >/dev/null" || fail 'pg_dump failed.'

# POSIX sh has no pipefail: record the producer's exit status separately.
{ app_compose exec -T db cat "$container_dump"; echo $? > "$status_file"; } |
    age -R "$recipient" -o "$partial"
[ "$(cat "$status_file")" = 0 ] || fail 'Streaming the dump out of the container failed.'
[ -s "$partial" ] || fail 'Encrypted backup is empty.'

final="$BACKUP_DIRECTORY/$name"
mv -- "$partial" "$final"
(cd "$BACKUP_DIRECTORY" && sha256sum "$name" > "$name.sha256")
log "Encrypted backup created: $final ($(wc -c < "$final") bytes)"

if [ -n "${BACKUP_RCLONE_REMOTE:-}" ]; then
    require_command rclone
    rclone copy --no-traverse "$final" "$BACKUP_RCLONE_REMOTE" &&
        rclone copy --no-traverse "$final.sha256" "$BACKUP_RCLONE_REMOTE" ||
        { send_alert "Backup $name was created locally but the off-host copy failed."; exit 1; }
    log "Off-host copy uploaded to $BACKUP_RCLONE_REMOTE"
else
    log 'WARNING: BACKUP_RCLONE_REMOTE is not set; this backup exists only on this VM.' >&2
fi

printf '%s\n' "$final" > "$BACKUP_DIRECTORY/.last-file"
date -u +%s > "$BACKUP_DIRECTORY/.last-success"

# Local retention only; off-host retention is managed by the bucket lifecycle policy.
find "$BACKUP_DIRECTORY" -maxdepth 1 -type f \( -name 'main-*.dump.age' -o -name 'main-*.dump.age.sha256' \) \
    -mtime "+$BACKUP_RETENTION_DAYS" -exec rm -f -- {} +
