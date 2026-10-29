#!/bin/sh
set -eu
script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$script_dir/common.sh"
require_command curl
require_command jq
public_url=${PUBLIC_API_URL:?Set PUBLIC_API_URL}
case "$public_url" in https://*) ;; *) fail 'The public API must use HTTPS.' ;; esac
public_url=${public_url%/}
owner=${SMOKE_OWNER_ID:?Set SMOKE_OWNER_ID to a dedicated staging customer}
beneficiary=${SMOKE_BENEFICIARY_ID:?Set SMOKE_BENEFICIARY_ID to an owned staging profile}
for id in "$owner" "$beneficiary"; do
    printf '%s\n' "$id" | grep -Eq '^[a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12}$' || fail 'Smoke owner and beneficiary IDs must be UUIDs.'
done
token=$(read_secret "${SMOKE_TOKEN_FILE:-/run/secrets/smoke_customer_token}")
printf '%s\n' "$token" | grep -Eq '^[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$' || fail 'Supply a current customer access token in the protected token file.'
gateway_key=$(read_secret /run/secrets/nutrition_gateway_key)
people_key=$(read_secret /run/secrets/nutrition_people_key)
create_work_directory
trap cleanup_work_directory EXIT
trap 'exit 1' HUP INT TERM
printf 'Authorization: Bearer %s\n' "$token" > "$work_dir/customer.headers"
printf 'x-nutrition-gateway-key: %s\n' "$gateway_key" > "$work_dir/gateway.headers"
printf 'X-Nutrition-Service-Key: %s\n' "$people_key" > "$work_dir/people.headers"
curl_check() {
    expected_status=$1; label=$2; shift 2
    status=$(curl --silent --show-error --connect-timeout 5 --max-time 20 --output "$work_dir/response" --write-out '%{http_code}' "$@")
    [ "$status" = "$expected_status" ] || fail "$label failed with HTTP $status."
    echo "$label passed."
}
curl_check 200 'Public API readiness' "$public_url/health/ready"
curl_check 401 'Unauthenticated Nutrition access rejected' "$public_url/api/v1/nutrition/capabilities"
curl_check 204 'Internal Identity session over HTTPS' --cacert /run/secrets/internal_ca \
    --header "@$work_dir/customer.headers" 'https://api:8443/api/v1/auth/session'
curl_check 200 'Internal Nutrition readiness over TLS/HTTP2' --http2 --cacert /run/secrets/internal_ca \
    'https://nutrition:8443/health/ready'
curl_check 200 'Internal People profile over HTTPS' --cacert /run/secrets/internal_ca \
    --header "@$work_dir/people.headers" "https://api:8443/internal/v1/nutrition/owners/$owner/beneficiaries/$beneficiary/health-profile"
jq -e --arg id "$beneficiary" '.beneficiaryId == $id and .revision >= 1' "$work_dir/response" >/dev/null || fail 'People profile response does not match its scope/revision.'
printf '\000\000\000\000\000' > "$work_dir/empty.grpc"
curl_check 200 'Internal Nutrition gRPC over TLS/HTTP2' --http2 --cacert /run/secrets/internal_ca \
    --header 'Content-Type: application/grpc' --header 'TE: trailers' \
    --header "@$work_dir/customer.headers" --header "@$work_dir/gateway.headers" \
    --data-binary "@$work_dir/empty.grpc" --dump-header "$work_dir/grpc.headers" \
    'https://nutrition:8443/caresitter.nutrition.v1.NutritionRpc/GetCapabilities'
tr -d '\r' < "$work_dir/grpc.headers" > "$work_dir/grpc.clean"
grep -Eq '^HTTP/2 200' "$work_dir/grpc.clean" && grep -Eiq '^grpc-status: 0$' "$work_dir/grpc.clean" || fail 'gRPC did not complete successfully over HTTP/2.'
curl_check 200 'Public REST to Nutrition gRPC' --header "@$work_dir/customer.headers" "$public_url/api/v1/nutrition/capabilities"
jq -e 'has("enabled") and has("assessmentsEnabled") and has("recommendationsEnabled") and has("freeTextParserReady")' "$work_dir/response" >/dev/null || fail 'Public Nutrition capabilities contract is incomplete.'
if [ "${EXPECT_NUTRITION_DEMO_FEATURES:-false}" = true ]; then
    jq -e '.enabled == true and .assessmentsEnabled == true and .recommendationsEnabled == true and .freeTextParserReady == true' \
        "$work_dir/response" >/dev/null || fail 'Demo Nutrition capabilities are not enabled.'
fi
curl_check 200 'Owned Nutrition meal plans' --header "@$work_dir/customer.headers" \
    "$public_url/api/v1/beneficiaries/$beneficiary/meal-plans"
jq -e 'type == "array"' "$work_dir/response" >/dev/null || fail 'Nutrition meal plans response is not an array.'
echo 'Nutrition connectivity smoke checks passed. Feature availability still depends on its flags and reviewed catalog.'
