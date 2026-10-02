#!/bin/sh
set -eu

# The demo seed contains known account password hashes and must never run here.
psql -v ON_ERROR_STOP=1 -q -c 'CREATE TABLE IF NOT EXISTS public.schema_migrations (filename text PRIMARY KEY, checksum_sha256 varchar(64) NOT NULL, applied_at timestamptz NOT NULL DEFAULT now())'

for file in /sql/[0-9][0-9]-*.sql; do
    [ -f "$file" ] || continue
    name=${file##*/}
    if [ "$name" = '09-seed.sql' ]; then
        echo "Skipping demo seed: $name"
        continue
    fi

    checksum=$(sha256sum "$file" | cut -d ' ' -f 1)
    stored=$(psql -v ON_ERROR_STOP=1 -Atq -c "SELECT checksum_sha256 FROM public.schema_migrations WHERE filename = '$name'")
    if [ "$stored" = "$checksum" ]; then
        echo "Already applied: $name"
        continue
    fi
    if [ -n "$stored" ]; then
        echo "Checksum mismatch: $name. Restore the original SQL and add a new migration." >&2
        exit 1
    fi
    case "$name" in
        19-drop-caregiver-availability.sql)
            legacy_object=$(psql -v ON_ERROR_STOP=1 -Atq -c "SELECT to_regclass('people.caregiver_availability') IS NOT NULL")
            if [ "$legacy_object" = 't' ] && [ "${ALLOW_DESTRUCTIVE_MIGRATIONS:-false}" != 'true' ]; then
                echo "Migration $name would drop an existing table. Review data, then set ALLOW_DESTRUCTIVE_MIGRATIONS=true." >&2
                exit 1
            fi
            ;;
        21-drop-caregiver-hourly-rate.sql)
            legacy_object=$(psql -v ON_ERROR_STOP=1 -Atq -c "SELECT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'people' AND table_name = 'caregiver_profiles' AND column_name = 'hourly_rate_expected')")
            if [ "$legacy_object" = 't' ] && [ "${ALLOW_DESTRUCTIVE_MIGRATIONS:-false}" != 'true' ]; then
                echo "Migration $name would drop an existing column. Review data, then set ALLOW_DESTRUCTIVE_MIGRATIONS=true." >&2
                exit 1
            fi
            ;;
    esac

    echo "Applying: $name"
    psql -v ON_ERROR_STOP=1 -q -f "$file"
    psql -v ON_ERROR_STOP=1 -q -c "INSERT INTO public.schema_migrations(filename, checksum_sha256) VALUES ('$name', '$checksum')"
done

echo 'Database migrations completed.'
