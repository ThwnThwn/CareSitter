#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo_dir=$(CDPATH= cd -- "$script_dir/../.." && pwd)
. "$script_dir/common.sh"
require_command docker
require_command sha256sum

main_env=${CARESITTER_DEPLOY_ENV_FILE:-"$repo_dir/deploy/.env"}
nutrition_env=${NUTRITION_DEPLOY_ENV_FILE:-"$repo_dir/deploy/nutrition.env"}
demo_env=${NUTRITION_DEMO_ENV_FILE:-"$repo_dir/deploy/nutrition.demo.env"}
for file in "$main_env" "$nutrition_env" "$demo_env"; do
    [ -f "$file" ] || fail 'Prepare all three deployment env files before the demo deployment.'
    [ "$(stat -c '%a' "$file")" = 600 ] || fail 'Deployment env files must have permission 0600.'
done

source_manifest="$repo_dir/deploy/source-manifest.sha256"
[ -f "$source_manifest" ] && [ -f "$repo_dir/deploy/source-revision.txt" ] ||
    fail 'Upload the local source package before running the Nutrition demo deployment.'
(cd "$repo_dir" && sha256sum -c deploy/source-manifest.sha256 >/dev/null 2>&1) ||
    fail 'The deployment source differs from the packaged local revision.'

app_environment=$(sed -n 's/^APP_ENVIRONMENT=//p' "$main_env" | tail -n 1)
[ "$app_environment" = Development ] || fail 'The owner-authorized Nutrition demo requires APP_ENVIRONMENT=Development.'

owner=$(sed -n 's/^NUTRITION_SMOKE_OWNER_ID=//p' "$nutrition_env" | tail -n 1)
beneficiary=$(sed -n 's/^NUTRITION_SMOKE_BENEFICIARY_ID=//p' "$nutrition_env" | tail -n 1)
for id in "$owner" "$beneficiary"; do
    printf '%s\n' "$id" | grep -Eq '^[a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12}$' ||
        fail 'Configure dedicated customer and beneficiary UUIDs for the mandatory Nutrition smoke test.'
done
smoke_token=$(sed -n 's/^NUTRITION_SMOKE_TOKEN_FILE=//p' "$nutrition_env" | tail -n 1)
smoke_token=${smoke_token:-./secrets/nutrition/customer-token}
case "$smoke_token" in
    /*) token_file=$smoke_token ;;
    *) token_file=$repo_dir/deploy/$smoke_token ;;
esac
[ -f "$token_file" ] && [ -r "$token_file" ] || fail 'Prepare the current customer token file before deploying.'
[ "$(stat -c '%a' "$token_file")" = 600 ] || fail 'The customer token file must have permission 0600.'

set -a
. "$demo_env"
set +a
catalog="$repo_dir/deploy/runtime/nutrition/catalog.import.bundle.json"
authorization="$repo_dir/deploy/runtime/nutrition/retrieval-authorization.json"
corpus="$repo_dir/deploy/runtime/nutrition/corpus.jsonl"
graph="$repo_dir/deploy/runtime/nutrition/graph.candidate.json"
gemini_key="$repo_dir/deploy/secrets/nutrition/gemini-api-key"

for binding in \
    "$catalog:${NUTRITION_DEMO_CATALOG_SHA256:?Missing catalog SHA-256}" \
    "$authorization:${NUTRITION_DEMO_AUTHORIZATION_SHA256:?Missing authorization SHA-256}" \
    "$corpus:${NUTRITION_DEMO_CORPUS_SHA256:?Missing corpus SHA-256}" \
    "$graph:${NUTRITION_DEMO_GRAPH_SHA256:?Missing graph SHA-256}"; do
    file=${binding%%:*}; expected=${binding#*:}
    [ -f "$file" ] && [ -r "$file" ] || fail 'A Nutrition demo runtime artifact is missing or unreadable.'
    actual=$(sha256sum "$file" | cut -d ' ' -f 1)
    [ "$(printf '%s' "$actual" | tr '[:lower:]' '[:upper:]')" = "$(printf '%s' "$expected" | tr '[:lower:]' '[:upper:]')" ] ||
        fail 'A Nutrition demo runtime artifact failed SHA-256 verification.'
done

key=$(read_secret "$gemini_key")
[ "${#key}" -ge 20 ] && [ "${#key}" -le 512 ] || fail 'Gemini API key length is invalid.'
[ "$(stat -c '%a' "$gemini_key")" = 400 ] || [ "$(stat -c '%a' "$gemini_key")" = 444 ] ||
    fail 'Gemini API key must have permission 0400 or 0444.'

(cd "$repo_dir" && sh deploy/nutrition/preflight.sh)
sh "$script_dir/demo-compose.sh" --profile nutrition-demo-seed config --quiet
echo 'Nutrition academic-demo deployment preflight passed.'
