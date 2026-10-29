#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$script_dir/common.sh"
require_command jq
require_command psql
require_command sha256sum
connect_nutrition_database

catalog=${NUTRITION_DEMO_CATALOG_PATH:?Set NUTRITION_DEMO_CATALOG_PATH}
expected_hash=${NUTRITION_DEMO_CATALOG_SHA256:?Set NUTRITION_DEMO_CATALOG_SHA256}
expected_recipes=${NUTRITION_DEMO_EXPECTED_RECIPES:-60}
package_key=${NUTRITION_DEMO_PACKAGE_KEY:-adult-baseline-p2a-v1-local-demo}

[ -f "$catalog" ] && [ -r "$catalog" ] || fail 'Nutrition demo catalog is missing or unreadable.'
printf '%s\n' "$expected_hash" | grep -Eq '^[a-fA-F0-9]{64}$' || fail 'Nutrition demo catalog SHA-256 is invalid.'
printf '%s\n' "$expected_recipes" | grep -Eq '^[1-9][0-9]*$' || fail 'Nutrition demo expected recipe count is invalid.'
printf '%s\n' "$package_key" | grep -Eq '^[a-z0-9]+(-[a-z0-9]+)*-local-demo$' || fail 'Nutrition demo package key is invalid.'

actual_hash=$(sha256sum "$catalog" | cut -d ' ' -f 1)
[ "$(printf '%s' "$actual_hash" | tr '[:lower:]' '[:upper:]')" = "$(printf '%s' "$expected_hash" | tr '[:lower:]' '[:upper:]')" ] ||
    fail 'Nutrition demo catalog SHA-256 does not match the deployment manifest.'

recipe_count=$(jq -er '.recipes | length' "$catalog")
[ "$recipe_count" = "$expected_recipes" ] || fail 'Nutrition demo catalog recipe count does not match the deployment manifest.'
catalog_package_key=$(jq -er '.packageKey' "$catalog")
[ "$catalog_package_key" = "$package_key" ] || fail 'Nutrition demo catalog package key does not match the deployment manifest.'

create_work_directory
trap cleanup_work_directory EXIT
trap 'exit 1' HUP INT TERM
jq -c . "$catalog" > "$work_dir/catalog.jsonl"
[ "$(wc -l < "$work_dir/catalog.jsonl" | tr -d ' ')" = 1 ] || fail 'Nutrition demo catalog could not be normalized.'

cat > "$work_dir/seed.sql" <<SQL
\set ON_ERROR_STOP on
CREATE TEMP TABLE demo_catalog_payload(payload text NOT NULL);
\copy demo_catalog_payload(payload) FROM '$work_dir/catalog.jsonl'
SELECT CASE
 WHEN current.payload = incoming.payload::jsonb THEN
  jsonb_build_object('packageKey', :'package_key', 'revision', current.revision,
    'status', 'local_demo', 'unchanged', true,
    'digest', current.payload_digest, 'productionPublishable', false)
 ELSE nutrition.import_local_demo_catalog(:'package_key', incoming.payload::jsonb)
 END AS result
FROM demo_catalog_payload incoming
LEFT JOIN nutrition.local_demo_catalog current ON current.package_key = :'package_key';
SELECT EXISTS (
 SELECT 1 FROM nutrition.local_demo_catalog
 WHERE package_key = :'package_key'
   AND jsonb_array_length(payload->'recipes') = :expected_recipes
) AS catalog_valid \gset
\if :catalog_valid
\else
\echo 'Nutrition demo catalog verification failed after import.'
\quit 3
\endif
SQL

psql -X -q -v ON_ERROR_STOP=1 -v package_key="$package_key" \
    -v expected_recipes="$expected_recipes" -f "$work_dir/seed.sql"
echo "Nutrition demo catalog is ready with $expected_recipes recipes."
