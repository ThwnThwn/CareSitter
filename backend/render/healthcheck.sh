#!/bin/bash
set -euo pipefail
if [[ "${RENDER_NUTRITION_ENABLED:-false}" == true ]]; then
    IFS= read -r root < /tmp/caresitter-render-ca.path
    [[ "$root" == /tmp/caresitter-render.*/ca.pem && -f "$root" ]]
    curl --fail --silent --show-error --max-time 4 --cacert "$root" \
        https://localhost:8443/health/ready >/dev/null
    curl --fail --silent --show-error --max-time 4 http://127.0.0.1:8081/health/live >/dev/null
else
    curl --fail --silent --show-error --max-time 4 "http://127.0.0.1:${PORT:-8080}/health/ready" >/dev/null
fi
