#!/bin/sh
# Restore drill: decrypt one main-DB backup into a throwaway PostGIS container
# and verify it. Run it on an operator machine or a separate host — anywhere the
# age PRIVATE key is available — never against the production database.
#
#   BACKUP_IDENTITY_FILE=~/keys/caresitter-backup.key \
#     sh deploy/ops/restore-check-main.sh /path/main-20261110T200000Z-scheduled.dump.age
#
# Exit 0 means: checksum matches, archive decrypts, restores without error, and
# the core schemas, migration ledger and key tables are present.
set -eu
umask 077
for command in docker age sha256sum; do
    command -v "$command" >/dev/null 2>&1 || { echo "Missing required command: $command" >&2; exit 1; }
done

backup_file=${1:?Pass one encrypted main backup file (main-*.dump.age)}
identity=${BACKUP_IDENTITY_FILE:?Set BACKUP_IDENTITY_FILE to the age private key file}
image=${RESTORE_IMAGE:-postgis/postgis:16-3.4}
case "${backup_file##*/}" in main-*.dump.age) ;; *) echo 'Unexpected backup filename.' >&2; exit 1 ;; esac
[ -f "$backup_file" ] && [ -f "$backup_file.sha256" ] || { echo 'Backup or .sha256 sidecar missing.' >&2; exit 1; }

expected=$(cut -d ' ' -f 1 "$backup_file.sha256")
printf '%s\n' "$expected" | grep -Eq '^[a-f0-9]{64}$' || { echo 'Invalid checksum sidecar.' >&2; exit 1; }
actual=$(sha256sum "$backup_file" | cut -d ' ' -f 1)
[ "$actual" = "$expected" ] || { echo 'Checksum mismatch: backup is corrupted or tampered.' >&2; exit 1; }

container="caresitter-restore-check-$(date +%s)-$$"
status_file=$(mktemp)
cleanup() { docker rm -f "$container" >/dev/null 2>&1 || true; rm -f -- "$status_file"; }
trap cleanup EXIT
trap 'exit 1' HUP INT TERM

docker run -d --name "$container" -e POSTGRES_PASSWORD="$(od -An -tx1 -N16 /dev/urandom | tr -d ' \n')" \
    -e POSTGRES_DB=restore "$image" >/dev/null
i=0
until docker exec "$container" pg_isready -U postgres -d restore >/dev/null 2>&1 &&
      [ "$(docker exec "$container" cat /proc/1/comm 2>/dev/null)" = postgres ]; do
    i=$((i + 1)); [ "$i" -lt 60 ] || { echo 'Restore database did not start.' >&2; exit 1; }
    sleep 1
done

docker exec "$container" createdb -U postgres --template=template0 drill
started=$(date +%s)
{ age -d -i "$identity" "$backup_file"; echo $? > "$status_file"; } |
    docker exec -i "$container" pg_restore --exit-on-error --no-owner -U postgres -d drill
[ "$(cat "$status_file")" = 0 ] || { echo 'Decryption failed.' >&2; exit 1; }
elapsed=$(( $(date +%s) - started ))

docker exec -i "$container" psql -X -q -v ON_ERROR_STOP=1 -U postgres -d drill <<'SQL'
DO $check$
DECLARE missing text;
BEGIN
  SELECT string_agg(s, ', ') INTO missing
  FROM unnest(ARRAY['identity','people','catalog','booking','payments','support','promotion']) s
  WHERE NOT EXISTS (SELECT 1 FROM pg_namespace WHERE nspname = s);
  IF missing IS NOT NULL THEN RAISE EXCEPTION 'Missing schemas: %', missing; END IF;
  IF (SELECT count(*) FROM public.schema_migrations) = 0 THEN
    RAISE EXCEPTION 'Migration ledger is empty';
  END IF;
END $check$;
\echo Restored row counts:
SELECT 'identity.users' AS table, count(*) FROM identity.users
UNION ALL SELECT 'booking.bookings', count(*) FROM booking.bookings
UNION ALL SELECT 'payments.wallet_accounts', count(*) FROM payments.wallet_accounts
UNION ALL SELECT 'catalog.service_types', count(*) FROM catalog.service_types
UNION ALL SELECT 'public.schema_migrations', count(*) FROM public.schema_migrations;
SQL

echo "PASS: ${backup_file##*/} restored and verified in ${elapsed}s (record this as the measured restore time)."
