#!/bin/sh
# Create the first SUPER_ADMIN on a fresh environment. The migration runner
# deliberately skips 09-seed.sql (demo accounts with known passwords), so
# production starts with no admin at all.
#
#   sh deploy/ops/create-admin.sh admin@your-domain.vn "Nguyen Van A" [0901234567]
#
# The password is read from the terminal (never from argv or shell history),
# hashed with BCrypt by the Caddy image already used by the stack, and only
# the hash is sent to PostgreSQL. Refuses to overwrite an existing account.
set -eu
repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
. "$repo_dir/deploy/ops/common.sh"
require_command docker

email=${1:?Usage: create-admin.sh <email> "<full name>" [phone]}
full_name=${2:?Usage: create-admin.sh <email> "<full name>" [phone]}
phone=${3:-}
printf '%s' "$email" | grep -Eq '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$' || fail 'Invalid email.'

if [ -t 0 ]; then
    stty -echo
    trap 'stty echo' EXIT
    printf 'Password (min 12 chars): ' >&2; IFS= read -r password; printf '\n' >&2
    printf 'Repeat password: ' >&2; IFS= read -r confirm; printf '\n' >&2
    stty echo
    trap - EXIT
    [ "$password" = "$confirm" ] || fail 'Passwords do not match.'
else
    IFS= read -r password   # non-interactive: first line of stdin
fi
[ "${#password}" -ge 12 ] || fail 'Password must be at least 12 characters.'

hash=$(printf '%s\n' "$password" | docker run --rm -i caddy:2-alpine caddy hash-password)
unset password confirm
printf '%s' "$hash" | grep -Eq '^\$2[aby]\$[0-9]{2}\$.{53}$' || fail 'Unexpected BCrypt hash format.'

app_compose exec -T db sh -c 'exec psql -X -q -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" "$@"' psql \
    -v email="$email" -v full_name="$full_name" -v phone="$phone" -v hash="$hash" <<'SQL'
SELECT EXISTS (SELECT 1 FROM identity.users WHERE lower(email) = lower(:'email') AND deleted_at IS NULL)
  AS account_exists \gset
\if :account_exists
\echo An account with this email already exists; promote or reset it from the admin web instead.
DO $stop$ BEGIN RAISE EXCEPTION 'account exists'; END $stop$;
\endif
INSERT INTO identity.users (email, phone, display_name, full_name, roles, status,
                            admin_department, admin_role, admin_is_active, password_hash)
VALUES (lower(:'email'), NULLIF(:'phone', ''), :'full_name', :'full_name', ARRAY['ADMIN']::varchar[], 'ACTIVE',
        'MANAGEMENT', 'SUPER_ADMIN', true, :'hash');
\echo Created SUPER_ADMIN account.
SQL
