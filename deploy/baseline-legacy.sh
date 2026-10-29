#!/bin/sh
set -eu

[ "${LEGACY_BASELINE_APPROVED:-false}" = true ] || {
    echo 'Set LEGACY_BASELINE_APPROVED=true only after auditing the old schema and migration history.' >&2
    exit 1
}
[ "${BACKUP_RESTORE_VERIFIED:-false}" = true ] || {
    echo 'A tested backup restore is required before baselining a legacy database.' >&2
    exit 1
}
expected=${LEGACY_BASELINE_EXPECTED_SHA256:-}
printf '%s\n' "$expected" | grep -Eq '^[a-f0-9]{64}$' || {
    echo 'Set LEGACY_BASELINE_EXPECTED_SHA256 to the audited 00-init.sql ledger checksum.' >&2
    exit 1
}

sql_dir=${CARESITTER_SQL_DIRECTORY:-/sql}
manifest=$sql_dir/00-init.sql
[ -f "$manifest" ] && [ -d "$sql_dir/modules" ] || {
    echo 'Missing CareSitter SQL manifest or modules directory.' >&2
    exit 1
}
actual=$(sha256sum "$manifest" | cut -d ' ' -f 1)
[ "$actual" = "$expected" ] || {
    echo 'The current 00-init.sql does not match the audited legacy checksum.' >&2
    exit 1
}

work_dir=$(mktemp -d)
trap 'rm -rf -- "$work_dir"' EXIT
trap 'exit 1' HUP INT TERM
awk '
    { sub(/\r$/, "") }
    $1 == "\\ir" {
        if (NF != 2 || $2 !~ /^modules\/[a-z0-9-]+\/[0-9][0-9]-[a-z0-9-]+\.sql$/) exit 1;
        print $2
    }
' "$manifest" > "$work_dir/manifest" || { echo 'Invalid SQL manifest.' >&2; exit 1; }
[ -s "$work_dir/manifest" ] || { echo 'SQL manifest is empty.' >&2; exit 1; }
(cd "$sql_dir" && find modules -type f -name '[0-9][0-9]-*.sql' | LC_ALL=C sort) > "$work_dir/discovered"
LC_ALL=C sort "$work_dir/manifest" > "$work_dir/listed"
cmp -s "$work_dir/discovered" "$work_dir/listed" || {
    echo 'Legacy manifest and nested migrations differ.' >&2
    exit 1
}
awk -F/ '{print $NF}' "$work_dir/manifest" | LC_ALL=C sort | uniq -d > "$work_dir/duplicates"
[ ! -s "$work_dir/duplicates" ] || { echo 'Duplicate migration basenames.' >&2; exit 1; }

cat > "$work_dir/baseline.sql" <<SQL
\set ON_ERROR_STOP on
SELECT pg_advisory_lock(hashtextextended('caresitter.main.schema', 0));
BEGIN;
DO \$guard\$ BEGIN
    IF to_regclass('public.schema_migrations') IS NULL THEN
        RAISE EXCEPTION 'Legacy ledger does not exist';
    END IF;
    IF (SELECT count(*) FROM public.schema_migrations) <> 1 OR NOT EXISTS (
        SELECT 1 FROM public.schema_migrations
        WHERE filename = '00-init.sql' AND checksum_sha256 = '$expected'
    ) THEN
        RAISE EXCEPTION 'Legacy ledger differs from the audited 00-init.sql record';
    END IF;
    IF to_regclass('identity.users') IS NULL OR
       to_regclass('people.caregiver_profiles') IS NULL OR
       to_regclass('booking.booking_chat_messages') IS NULL OR
       to_regclass('support.chat_messages') IS NULL OR
       to_regclass('payments.wallet_accounts') IS NULL OR
       to_regclass('promotion.promotions') IS NULL THEN
        RAISE EXCEPTION 'Expected legacy schema objects are missing';
    END IF;
END \$guard\$;
CREATE TABLE IF NOT EXISTS public.schema_migration_baselines (
    manifest_checksum_sha256 varchar(64) PRIMARY KEY,
    recorded_at timestamptz NOT NULL DEFAULT now()
);
REVOKE ALL ON public.schema_migration_baselines FROM PUBLIC;
INSERT INTO public.schema_migration_baselines(manifest_checksum_sha256) VALUES ('$expected');
DELETE FROM public.schema_migrations WHERE filename = '00-init.sql';
SQL

count=0
while IFS= read -r relative; do
    name=${relative##*/}
    case "$name" in *-seed*.sql|*-demo*.sql) continue ;; esac
    checksum=$(sed 's/\r$//' "$sql_dir/$relative" | sha256sum | cut -d ' ' -f 1)
    printf "INSERT INTO public.schema_migrations(filename, checksum_sha256) VALUES ('%s', '%s');\n" \
        "$name" "$checksum" >> "$work_dir/baseline.sql"
    count=$((count+1))
done < "$work_dir/manifest"
[ "$count" -gt 0 ] || { echo 'No schema migrations to baseline.' >&2; exit 1; }
cat >> "$work_dir/baseline.sql" <<'SQL'
COMMIT;
SELECT pg_advisory_unlock(hashtextextended('caresitter.main.schema', 0));
SQL
psql -X -q -v ON_ERROR_STOP=1 -f "$work_dir/baseline.sql"
echo "Baselined $count verified migration files. Audit and remove any legacy demo accounts/data before production."
