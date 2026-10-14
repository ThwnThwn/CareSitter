#!/bin/sh
set -eu
script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$script_dir/common.sh"
for command in psql createdb dropdb pg_restore age sha256sum openssl; do require_command "$command"; done
connect_nutrition_database
identity_file=${BACKUP_IDENTITY_FILE:?Set BACKUP_IDENTITY_FILE}
read_secret "$identity_file" >/dev/null
backup_file=${1:?Pass one encrypted nutrition backup file}
[ -f "$backup_file" ] && [ -f "$backup_file.sha256" ] || fail 'Backup or checksum sidecar is missing.'
backup_parent=$(CDPATH= cd -- "$(dirname -- "$backup_file")" && pwd)
backup_name=${backup_file##*/}
case "$backup_name" in nutrition-*.dump.age) ;; *) fail 'Unexpected nutrition backup filename.' ;; esac
# Never interpret arbitrary paths from a modified checksum sidecar.
expected=$(cut -d ' ' -f 1 "$backup_file.sha256")
printf '%s\n' "$expected" | grep -Eq '^[a-f0-9]{64}$' || fail 'Invalid backup checksum.'
actual=$(sha256sum "$backup_file" | cut -d ' ' -f 1)
[ "$actual" = "$expected" ] || fail 'Encrypted backup checksum does not match.'
create_work_directory
scratch_database="nutrition_restore_$(openssl rand -hex 8)"
scratch_created=false
cleanup() {
    if [ "$scratch_created" = true ]; then
        case "$scratch_database" in nutrition_restore_*) dropdb --if-exists "$scratch_database" ;; *) return 1 ;; esac
    fi
    cleanup_work_directory
}
trap cleanup EXIT
trap 'exit 1' HUP INT TERM
age -d -i "$identity_file" -o "$work_dir/nutrition.dump" "$backup_parent/$backup_name"
createdb "$scratch_database"
scratch_created=true
# Restore only into a newly created scratch DB, retaining ACLs and RLS. No --clean/--create against the source.
pg_restore --exit-on-error --single-transaction --no-owner --dbname="$scratch_database" "$work_dir/nutrition.dump"
cat > "$work_dir/assert.sql" <<'SQL'
DO $check$
BEGIN
 IF (SELECT count(*) FROM information_schema.tables WHERE table_schema='nutrition' AND table_type='BASE TABLE') <> 9 THEN
  RAISE EXCEPTION 'Nutrition table count mismatch';
 END IF;
 IF (SELECT count(*) FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
     WHERE n.nspname='nutrition' AND c.relname IN ('assessments','recommendations','meal_plans','preferences')
       AND c.relrowsecurity AND c.relforcerowsecurity) <> 4 THEN
  RAISE EXCEPTION 'Restored RLS protection is incomplete';
 END IF;
 IF (SELECT count(*) FROM pg_policies WHERE schemaname='nutrition' AND policyname='owner_access') <> 4 THEN
  RAISE EXCEPTION 'Restored owner policies are incomplete';
 END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='nutrition_app' AND rolcanlogin AND NOT rolsuper AND NOT rolbypassrls) THEN
  RAISE EXCEPTION 'Restricted runtime role is unavailable';
 END IF;
 IF has_table_privilege('nutrition_app','nutrition.recipe_versions','INSERT') OR
    NOT has_table_privilege('nutrition_app','nutrition.assessments','SELECT,INSERT,UPDATE,DELETE') THEN
  RAISE EXCEPTION 'Restored runtime ACL mismatch';
 END IF;
 IF (SELECT count(*) FROM public.nutrition_schema_migrations) < 2 THEN
  RAISE EXCEPTION 'Restored migration ledger is incomplete';
 END IF;
END $check$;
SQL
psql -X -q -v ON_ERROR_STOP=1 --dbname="$scratch_database" -f "$work_dir/assert.sql"
echo 'Nutrition backup restored and schema, ACL, RLS and ledger verified in a temporary database.'
