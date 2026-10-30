#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$script_dir/common.sh"
require_command curl
require_command docker

skip_build=false
for argument in "$@"; do
    case "$argument" in
        --skip-build) skip_build=true ;;
        --smoke) ;; # Kept for callers that used the old opt-in flag.
        *) fail 'Usage: deploy-demo.sh [--skip-build]' ;;
    esac
done

# Generate only missing internal credentials/certificates and preserve every existing secret.
sh "$script_dir/prepare-secrets.sh"
sh "$script_dir/preflight-demo.sh"
compose="$script_dir/demo-compose.sh"
if [ "$skip_build" = false ]; then
    sh "$compose" --profile nutrition-demo-seed build api admin nutrition nutrition-demo-catalog
fi
sh "$compose" up -d db redis nutrition-db
sh "$compose" run --rm migrate
sh "$compose" run --rm nutrition-migrate
sh "$compose" --profile nutrition-demo-seed run --rm nutrition-demo-catalog
sh "$compose" up -d --wait api admin nutrition proxy

repo_dir=$(CDPATH= cd -- "$script_dir/../.." && pwd)
main_env=${CARESITTER_DEPLOY_ENV_FILE:-"$repo_dir/deploy/.env"}
domain=$(sed -n 's/^APP_DOMAIN=//p' "$main_env" | tail -n 1)
[ -n "$domain" ] || fail 'APP_DOMAIN is missing.'
ready=false
for attempt in $(seq 1 30); do
    if curl --fail --silent --show-error --connect-timeout 5 --max-time 15 "https://$domain/health/ready" >/dev/null 2>&1; then
        ready=true
        break
    fi
    sleep 3
done
[ "$ready" = true ] || fail 'Public HTTPS readiness did not pass within 90 seconds.'
echo "CareSitter demo readiness passed at https://$domain/health/ready."

sh "$compose" --profile nutrition-smoke run --rm nutrition-smoke
echo 'CareSitter Nutrition demo deployment completed.'
