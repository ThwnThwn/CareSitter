#!/bin/sh
# Offline contract checks: curl is replaced by a function; no network is used.
set -eu
script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
export HealthParser__Enabled=false MealRanking__Enabled=false
(
    curl() { echo 'Unexpected probe for disabled AI.' >&2; exit 99; }
    . "$script_dir/check-ai-egress.sh"
)
(
    export HealthParser__Enabled=TRUE
    export HealthParser__BaseUrl='https://api.openai.com/v1/private?key=fixture'
    curl() {
        [ "$*" = '-q --noproxy * --proto =https --head --silent --connect-timeout 5 --max-time 10 --output /dev/null https://api.openai.com/' ] || exit 98
    }
    . "$script_dir/check-ai-egress.sh"
)
if (
    export MealRanking__Enabled=true
    curl() { return 6; }
    . "$script_dir/check-ai-egress.sh"
); then
    echo 'Failed DNS/TLS must fail the runtime probe.' >&2; exit 1
fi
if (
    export HealthParser__Enabled=true HealthParser__BaseUrl='http://invalid.test/'
    curl() { exit 97; }
    . "$script_dir/check-ai-egress.sh"
); then
    echo 'Non-HTTPS provider must fail the runtime probe.' >&2; exit 1
fi
echo 'PASS: disabled flags skip probes; enabled AI uses authority-only HEAD; DNS/TLS failures and HTTP are rejected.'
