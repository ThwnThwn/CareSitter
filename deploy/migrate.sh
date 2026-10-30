#!/bin/sh
set -eu

sql_dir=${CARESITTER_SQL_DIRECTORY:-/sql}
manifest=$sql_dir/00-init.sql
[ -f "$manifest" ] && [ -d "$sql_dir/modules" ] || {
    echo 'Missing CareSitter SQL manifest or modules directory.' >&2
    exit 1
}
for command in awk cmp find grep mktemp psql sed sha256sum sort uniq; do
    command -v "$command" >/dev/null 2>&1 || { echo "Missing command: $command" >&2; exit 1; }
done

work_dir=$(mktemp -d)
trap 'rm -rf -- "$work_dir"' EXIT
trap 'exit 1' HUP INT TERM

# 00-init.sql is the bootstrap manifest. Importing it directly would also run
# demo accounts and bypass the destructive-migration guards below.
awk '
    { sub(/\r$/, "") }
    $1 == "\\ir" {
        if (NF != 2 || $2 !~ /^modules\/[a-z0-9-]+\/[0-9][0-9]-[a-z0-9-]+\.sql$/) exit 1;
        print $2
    }
' "$manifest" > "$work_dir/manifest" || { echo 'Invalid SQL manifest entry.' >&2; exit 1; }
[ -s "$work_dir/manifest" ] || { echo 'SQL manifest has no module migrations.' >&2; exit 1; }
(cd "$sql_dir" && find modules -type f -name '[0-9][0-9]-*.sql' | LC_ALL=C sort) > "$work_dir/discovered"
LC_ALL=C sort "$work_dir/manifest" > "$work_dir/listed"
cmp -s "$work_dir/discovered" "$work_dir/listed" || {
    echo 'SQL manifest and nested migration files differ; update 00-init.sql before deploying.' >&2
    exit 1
}
awk -F/ '{print $NF}' "$work_dir/manifest" | LC_ALL=C sort | uniq -d > "$work_dir/duplicate-names"
[ ! -s "$work_dir/duplicate-names" ] || { echo 'Migration basenames must be unique.' >&2; exit 1; }

cat > "$work_dir/run.sql" <<'SQL'
\set ON_ERROR_STOP on
SELECT pg_advisory_lock(hashtextextended('caresitter.main.schema', 0));
SELECT NOT EXISTS (
    SELECT 1 FROM pg_namespace
    WHERE nspname IN ('identity', 'people', 'catalog', 'booking', 'payments', 'support', 'promotion')
) AS fresh_database \gset
CREATE TABLE IF NOT EXISTS public.schema_migrations (
    filename text PRIMARY KEY,
    checksum_sha256 varchar(64) NOT NULL,
    applied_at timestamptz NOT NULL DEFAULT now()
);
REVOKE ALL ON public.schema_migrations FROM PUBLIC;
DO $guard$ BEGIN
    IF EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '00-init.sql') THEN
        RAISE EXCEPTION 'Legacy 00-init.sql ledger needs an audited baseline before this runner can upgrade it';
    END IF;
    IF EXISTS (
        SELECT 1 FROM pg_namespace
        WHERE nspname IN ('identity', 'people', 'catalog', 'booking', 'payments', 'support', 'promotion')
    ) AND NOT EXISTS (SELECT 1 FROM public.schema_migrations) THEN
        RAISE EXCEPTION 'Existing CareSitter schema has no per-file ledger; audit and baseline it before upgrade';
    END IF;
END $guard$;
SQL

while IFS= read -r relative; do
    file=$sql_dir/$relative
    name=${relative##*/}
    case "$name" in
        *-seed*.sql|*-demo*.sql)
            echo "Skipping demo data: $name"
            continue
            ;;
    esac

    # Normalise Windows/Linux checkout line endings without changing SQL source.
    checksum=$(sed 's/\r$//' "$file" | sha256sum | cut -d ' ' -f 1)
    raw_checksum=$(sha256sum "$file" | cut -d ' ' -f 1)
    crlf_checksum=$(sed 's/\r$//' "$file" | sed 's/$/\r/' | sha256sum | cut -d ' ' -f 1)
    cat >> "$work_dir/run.sql" <<SQL
DO \$guard\$ BEGIN
    IF EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '$name'
        AND checksum_sha256 NOT IN ('$checksum', '$raw_checksum', '$crlf_checksum')) THEN
        RAISE EXCEPTION 'Applied migration checksum changed: $name';
    END IF;
END \$guard\$;
UPDATE public.schema_migrations SET checksum_sha256 = '$checksum'
WHERE filename = '$name' AND checksum_sha256 IN ('$raw_checksum', '$crlf_checksum');
SELECT NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE filename = '$name') AS apply_migration \gset
\if :apply_migration
SQL
    if [ "${ALLOW_DESTRUCTIVE_MIGRATIONS:-false}" != true ]; then
        case "$name" in
            19-drop-caregiver-availability.sql)
                cat >> "$work_dir/run.sql" <<'SQL'
\if :fresh_database
\else
DO $guard$ BEGIN
    IF to_regclass('people.caregiver_availability') IS NOT NULL THEN
        RAISE EXCEPTION 'Migration 19 would drop an existing table; review data and set ALLOW_DESTRUCTIVE_MIGRATIONS=true';
    END IF;
END $guard$;
\endif
SQL
                ;;
            21-drop-caregiver-hourly-rate.sql)
                cat >> "$work_dir/run.sql" <<'SQL'
\if :fresh_database
\else
DO $guard$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'people'
        AND table_name = 'caregiver_profiles' AND column_name = 'hourly_rate_expected') THEN
        RAISE EXCEPTION 'Migration 21 would drop an existing column; review data and set ALLOW_DESTRUCTIVE_MIGRATIONS=true';
    END IF;
END $guard$;
\endif
SQL
                ;;
        esac
    fi
    printf 'BEGIN;\n' >> "$work_dir/run.sql"
    # Historical files sometimes contain one outer transaction pair. Strip only
    # that pair so the source and ledger insertion commit or roll back together.
    awk '
        { sub(/\r$/, ""); line[NR]=$0;
          if ($0 !~ /^[[:space:]]*$/ && $0 !~ /^[[:space:]]*--/) {
              if (!first) first=NR;
              last=NR;
          }
        }
        END {
            wrapped=(line[first]=="BEGIN;" && line[last]=="COMMIT;");
            if ((line[first]=="BEGIN;" || line[last]=="COMMIT;") && !wrapped) exit 1;
            for (i=1; i<=NR; i++) {
                if ((line[i]=="BEGIN;" || line[i]=="COMMIT;") &&
                    (!wrapped || (i!=first && i!=last))) exit 1;
            }
            for (i=1; i<=NR; i++) if (!wrapped || (i!=first && i!=last)) print line[i];
        }
    ' "$file" >> "$work_dir/run.sql" || {
        echo "Unexpected transaction boundary in $name." >&2
        exit 1
    }
    cat >> "$work_dir/run.sql" <<SQL
INSERT INTO public.schema_migrations(filename, checksum_sha256) VALUES ('$name', '$checksum');
COMMIT;
\echo Applied $name
\else
\echo Already applied $name
\endif
SQL
done < "$work_dir/manifest"

printf '%s\n' "SELECT pg_advisory_unlock(hashtextextended('caresitter.main.schema', 0));" >> "$work_dir/run.sql"
psql -X -q -v ON_ERROR_STOP=1 -f "$work_dir/run.sql"
echo 'CareSitter migration ledger verified.'
