#!/bin/sh
set -eu
script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$script_dir/common.sh"
require_command psql
require_command sha256sum
connect_nutrition_database
sql_dir=${NUTRITION_SQL_DIRECTORY:?Set NUTRITION_SQL_DIRECTORY}
[ -d "$sql_dir" ] || fail 'Nutrition SQL directory does not exist.'
NUTRITION_DB_APP_PASSWORD=$(read_secret "${NUTRITION_APP_PASSWORD_FILE:?Set NUTRITION_APP_PASSWORD_FILE}")
export NUTRITION_DB_APP_PASSWORD
create_work_directory
trap cleanup_work_directory EXIT
trap 'exit 1' HUP INT TERM

cat > "$work_dir/migrate.sql" <<'SQL'
\set ON_ERROR_STOP on
\getenv app_password NUTRITION_DB_APP_PASSWORD
SELECT pg_advisory_lock(hashtextextended('caresitter.nutrition.schema', 0));
CREATE TABLE IF NOT EXISTS public.nutrition_schema_migrations (
 filename text PRIMARY KEY, sha256 text NOT NULL, applied_at timestamptz NOT NULL DEFAULT now()
);
REVOKE ALL ON public.nutrition_schema_migrations FROM PUBLIC;
SQL

count=0
for migration in "$sql_dir"/*.sql; do
    [ -f "$migration" ] || continue
    filename=${migration##*/}
    printf '%s\n' "$filename" | grep -Eq '^[0-9][0-9]-[a-z0-9-]+\.sql$' || fail 'Invalid migration filename.'
    # Line-ending conversion during a Windows/Linux checkout must not change the migration identity.
    checksum=$(sed 's/\r$//' "$migration" | sha256sum | cut -d ' ' -f 1)
    cat >> "$work_dir/migrate.sql" <<SQL
DO \$guard\$ BEGIN
 IF EXISTS (SELECT 1 FROM public.nutrition_schema_migrations WHERE filename='$filename' AND sha256<>'$checksum') THEN
  RAISE EXCEPTION 'Applied migration checksum changed: $filename';
 END IF;
END \$guard\$;
SELECT NOT EXISTS (SELECT 1 FROM public.nutrition_schema_migrations WHERE filename='$filename') AS apply_migration \gset
\if :apply_migration
BEGIN;
SQL
    # Wrap source and ledger insertion in one transaction, including legacy outer BEGIN/COMMIT.
    # Source files remain immutable. Only their exact outer transaction pair is stripped.
    awk '
      { sub(/\r$/, ""); line[NR]=$0; if ($0 !~ /^[[:space:]]*$/ && $0 !~ /^[[:space:]]*--/) { if (!first) first=NR; last=NR } }
      END {
        wrapped=(line[first]=="BEGIN;" && line[last]=="COMMIT;");
        if ((line[first]=="BEGIN;" || line[last]=="COMMIT;") && !wrapped) exit 1;
        for (i=1; i<=NR; i++) if ((line[i]=="BEGIN;" || line[i]=="COMMIT;") && (!wrapped || (i!=first && i!=last))) exit 1;
        for (i=1; i<=NR; i++) if (!wrapped || (i!=first && i!=last)) print line[i];
      }' "$migration" >> "$work_dir/migrate.sql" || fail 'Unexpected outer migration transaction.'
    cat >> "$work_dir/migrate.sql" <<SQL
INSERT INTO public.nutrition_schema_migrations(filename,sha256) VALUES ('$filename','$checksum');
COMMIT;
\echo Applied $filename
\else
\echo Already applied $filename
\endif
SQL
    count=$((count+1))
done
[ "$count" -gt 0 ] || fail 'No nutrition SQL migrations were found.'
printf '%s\n' "SELECT pg_advisory_unlock(hashtextextended('caresitter.nutrition.schema', 0));" >> "$work_dir/migrate.sql"
# -X disables user psql startup files. Errors roll back the current migration and release the lock.
# Role provisioning carries a password; suppress SQL statement logging for this admin session only.
PGOPTIONS='-c log_statement=none -c log_min_error_statement=panic'
export PGOPTIONS
psql -X -q -v ON_ERROR_STOP=1 -f "$work_dir/migrate.sql"
echo 'Nutrition migration ledger verified.'
