#!/bin/sh
set -eu
script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo_dir=$(CDPATH= cd -- "$script_dir/../.." && pwd)
. "$script_dir/common.sh"
require_command openssl
require_command docker
require_command age-keygen
main_env=${CARESITTER_DEPLOY_ENV_FILE:-"$repo_dir/deploy/.env"}
nutrition_env=${NUTRITION_DEPLOY_ENV_FILE:-"$repo_dir/deploy/nutrition.env"}
secret_dir="$repo_dir/deploy/secrets/nutrition"
recovery_dir="$repo_dir/deploy/secrets/nutrition-recovery"
(cd "$repo_dir" && sh deploy/preflight.sh "$main_env")
[ -f "$nutrition_env" ] || fail 'Prepare deploy/nutrition.env before deployment.'
for file in "$main_env" "$nutrition_env"; do
    [ "$(stat -c '%a' "$file")" = 600 ] || fail 'Deployment env files must have permission 0600.'
done
# AI providers: fail here with a clear message instead of a crash-looping container.
nutrition_value() { sed -n "s/^$1=//p" "$nutrition_env" | tail -n 1; }
for feature in HEALTH_PARSER MEAL_RANKING; do
    [ "$(nutrition_value "NUTRITION_${feature}_ENABLED")" = true ] || continue
    key=$(nutrition_value "NUTRITION_${feature}_API_KEY")
    [ "${#key}" -ge 20 ] || fail "NUTRITION_${feature}_ENABLED=true needs NUTRITION_${feature}_API_KEY (20+ characters)."
    [ "$(nutrition_value "NUTRITION_${feature}_DATA_PROCESSING_APPROVED")" = true ] ||
        fail "NUTRITION_${feature}_ENABLED=true needs NUTRITION_${feature}_DATA_PROCESSING_APPROVED=true (owner sign-off)."
done
if [ "$(nutrition_value NUTRITION_MEAL_RANKING_ENABLED)" = true ] &&
    [ "$(nutrition_value NUTRITION_RECOMMENDATIONS_ENABLED)" != true ]; then
    fail 'NUTRITION_MEAL_RANKING_ENABLED=true has no effect while NUTRITION_RECOMMENDATIONS_ENABLED=false.'
fi
if [ "$(nutrition_value NUTRITION_RECOMMENDATIONS_ENABLED)" = true ]; then
    echo 'NOTE: recommendations are on; /health/ready fails until a reviewed catalog is published (CatalogTool publish).' >&2
fi
# The standalone staging package is intended for a Linux host.
for directory in "$secret_dir" "$recovery_dir"; do
    [ -d "$directory" ] && [ "$(stat -c '%a' "$directory")" = 700 ] || fail 'Nutrition secret directories must have permission 0700.'
done
for name in db-admin-password db-app-password gateway-key people-key tls-password; do
    value=$(read_secret "$secret_dir/$name")
    printf '%s\n' "$value" | grep -Eq '^[a-f0-9]{64}$' || fail 'Nutrition generated credentials must contain 64 hexadecimal characters.'
done
[ "$(stat -c '%a' "$recovery_dir/age-identity")" = 600 ] || fail 'The backup recovery identity must have permission 0600.'
[ "$(stat -c '%a' "$secret_dir/ca-key.pem")" = 600 ] || fail 'The internal CA private key must have permission 0600.'
read_secret "$secret_dir/backup-recipient" >/dev/null
create_work_directory
trap cleanup_work_directory EXIT
trap 'exit 1' HUP INT TERM
age-keygen -y "$recovery_dir/age-identity" > "$work_dir/backup-recipient"
cmp -s "$work_dir/backup-recipient" "$secret_dir/backup-recipient" || fail 'Backup recipient and recovery identity do not match.'
for name in api nutrition; do
    openssl pkcs12 -in "$secret_dir/$name.pfx" -passin "file:$secret_dir/tls-password" -clcerts -nokeys -out "$work_dir/$name.pem" 2>/dev/null || fail 'Unable to read an internal TLS certificate.'
    openssl verify -purpose sslserver -verify_hostname "$name" -CAfile "$secret_dir/ca.pem" "$work_dir/$name.pem" >/dev/null 2>&1 || fail 'An internal TLS certificate does not match its CA/hostname/purpose.'
    openssl x509 -in "$work_dir/$name.pem" -checkend 604800 -noout >/dev/null || fail 'An internal TLS certificate expires within seven days; renew it before deployment.'
done
sh "$script_dir/compose.sh" --profile baseline-legacy --profile nutrition-migrate --profile nutrition-ops --profile nutrition-smoke config --quiet
sh "$script_dir/compose.sh" run --rm nutrition-catalog-check
if [ "${NUTRITION_CHECK_AI_EGRESS:-false}" = true ]; then
    sh "$script_dir/compose.sh" exec -T nutrition sh -s < "$script_dir/check-ai-egress.sh"
else
    echo 'AI runtime egress not checked. After startup, set NUTRITION_CHECK_AI_EGRESS=true to probe from Nutrition.'
fi
echo 'Nutrition deployment preflight passed. Runtime checks still require the target host.'
