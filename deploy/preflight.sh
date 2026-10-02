#!/bin/sh
set -eu

env_file=${1:-deploy/.env}
if [ ! -f "$env_file" ]; then
    echo "Missing deployment environment file: $env_file" >&2
    exit 1
fi
if grep -Ev '^[[:space:]]*(#|$)' "$env_file" | grep -Eq 'REPLACE_WITH|example\.com'; then
    echo 'Deployment configuration still contains example domains or placeholder credentials.' >&2
    exit 1
fi
if [ ! -f deploy/secrets/firebase-service-account.json ]; then
    echo 'Missing deploy/secrets/firebase-service-account.json.' >&2
    exit 1
fi

echo 'Deployment files are present and contain no example placeholders.'
