#!/bin/sh
set -eu
repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
main_env=${CARESITTER_DEPLOY_ENV_FILE:-"$repo_dir/deploy/.env"}
nutrition_env=${NUTRITION_DEPLOY_ENV_FILE:-"$repo_dir/deploy/nutrition.env"}
[ -f "$main_env" ] && [ -f "$nutrition_env" ] || {
    echo 'Prepare the main deployment env and deploy/nutrition.env first.' >&2; exit 1;
}
export CARESITTER_ENV_FILE="$main_env"
exec docker compose --project-directory "$repo_dir/deploy" --env-file "$main_env" \
    --env-file "$nutrition_env" -f "$repo_dir/deploy/compose.yml" \
    -f "$repo_dir/deploy/nutrition/compose.yml" "$@"
