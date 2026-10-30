#!/bin/sh
set -eu

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
main_env=${CARESITTER_DEPLOY_ENV_FILE:-"$repo_dir/deploy/.env"}
nutrition_env=${NUTRITION_DEPLOY_ENV_FILE:-"$repo_dir/deploy/nutrition.env"}
demo_env=${NUTRITION_DEMO_ENV_FILE:-"$repo_dir/deploy/nutrition.demo.env"}
for file in "$main_env" "$nutrition_env" "$demo_env"; do
    [ -f "$file" ] || { echo "Missing deployment env file: $file" >&2; exit 1; }
done
export CARESITTER_ENV_FILE="$main_env"
exec docker compose --project-directory "$repo_dir/deploy" \
    --env-file "$main_env" --env-file "$nutrition_env" --env-file "$demo_env" \
    -f "$repo_dir/deploy/compose.yml" \
    -f "$repo_dir/deploy/nutrition/compose.yml" \
    -f "$repo_dir/deploy/nutrition/compose.demo.yml" "$@"
