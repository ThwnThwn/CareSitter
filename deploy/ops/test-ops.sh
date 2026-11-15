#!/bin/sh
# Integration test for the host operations scripts against a disposable stack:
# migrate → create-admin (+ duplicate refusal) → encrypted backup → restore
# drill → tamper detection. Needs docker (with compose), age, curl, openssl.
#   sh deploy/ops/test-ops.sh
set -eu
repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
cd "$repo_dir"

work=$(mktemp -d)
export COMPOSE_PROJECT_NAME="caresitter-opstest-$$"
export CARESITTER_ENV_FILE="$work/app.env" CARESITTER_COMPOSE_OVERLAY=none RELEASE_TAG=opstest
export APP_ENVIRONMENT=Staging POSTGRES_DB=caresitter POSTGRES_USER=caresitter
export POSTGRES_PASSWORD="pg-$(od -An -tx1 -N12 /dev/urandom | tr -d ' \n')"
export REDIS_PASSWORD="rd-$(od -An -tx1 -N12 /dev/urandom | tr -d ' \n')"
export EDGE_SUBNET=172.31.251.0/24 PROXY_IP=172.31.251.10
export BACKUP_DIRECTORY="$work/backups" BACKUP_RECIPIENT_FILE="$work/recipient.txt"
: > "$CARESITTER_ENV_FILE"

compose() { sh deploy/app-compose.sh "$@"; }
cleanup() {
    compose down -v --remove-orphans >/dev/null 2>&1 || true
    rm -rf -- "$work"
}
trap cleanup EXIT
trap 'exit 1' HUP INT TERM
pass() { echo "PASS: $*"; }

age-keygen -o "$work/backup.key" 2>/dev/null
age-keygen -y "$work/backup.key" > "$BACKUP_RECIPIENT_FILE"

compose up -d --wait db
compose run --rm migrate >/dev/null
pass 'fresh database migrated through deploy/migrate.sh'

printf '%s\n' 'Ops-Test-Password-2026' | sh deploy/ops/create-admin.sh Ops.Admin@Example.org 'Ops Test Admin' >/dev/null
row=$(compose exec -T db sh -c 'psql -X -At -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "SELECT email, roles[1], admin_role, left(password_hash, 7) FROM identity.users"')
[ "$row" = 'ops.admin@example.org|ADMIN|SUPER_ADMIN|$2a$14$' ] || { echo "Unexpected admin row: $row" >&2; exit 1; }
pass 'create-admin stores a lower-cased SUPER_ADMIN with a BCrypt hash'

if printf '%s\n' 'Another-Password-2026' | sh deploy/ops/create-admin.sh ops.admin@example.org 'Dup' >/dev/null 2>&1; then
    echo 'Duplicate admin creation should have failed.' >&2; exit 1
fi
count=$(compose exec -T db sh -c 'psql -X -At -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "SELECT count(*) FROM identity.users"')
[ "$count" = 1 ] || { echo "Duplicate run changed users: $count" >&2; exit 1; }
pass 'create-admin refuses an existing email'

sh deploy/ops/backup-main.sh test >/dev/null 2>&1
backup=$(cat "$BACKUP_DIRECTORY/.last-file")
[ -s "$backup" ] && [ -s "$backup.sha256" ] && [ -f "$BACKUP_DIRECTORY/.last-success" ] ||
    { echo 'Backup artifacts missing.' >&2; exit 1; }
if head -c 5 "$backup" | grep -q PGDMP; then echo 'Backup is not encrypted.' >&2; exit 1; fi
pass 'backup-main writes an age-encrypted dump with checksum and freshness marker'

BACKUP_IDENTITY_FILE="$work/backup.key" sh deploy/ops/restore-check-main.sh "$backup" > "$work/restore.log"
grep -q '^PASS:' "$work/restore.log" || { cat "$work/restore.log" >&2; exit 1; }
pass 'restore drill decrypts, restores and verifies the backup'

tampered="$BACKUP_DIRECTORY/main-tampered-test.dump.age"
cp "$backup" "$tampered"; cp "$backup.sha256" "$tampered.sha256"
printf 'x' >> "$tampered"
if BACKUP_IDENTITY_FILE="$work/backup.key" sh deploy/ops/restore-check-main.sh "$tampered" >/dev/null 2>&1; then
    echo 'Tampered backup was accepted.' >&2; exit 1
fi
pass 'restore drill rejects a backup whose checksum does not match'
