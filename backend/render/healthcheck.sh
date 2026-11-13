#!/bin/bash
set -euo pipefail
if [[ "${RENDER_NUTRITION_ENABLED:-false}" == true ]]; then
    roots=(/tmp/caresitter-render.*/ca.pem)
    [[ ${#roots[@]} == 1 && -f "${roots[0]}" ]]
    curl --fail --silent --show-error --max-time 4 --cacert "${roots[0]}" \
        https://localhost:8443/health/ready >/dev/null
    curl --fail --silent --show-error --max-time 4 http://127.0.0.1:8081/health/live >/dev/null
else
    curl --fail --silent --show-error --max-time 4 "http://127.0.0.1:${PORT:-8080}/health/ready" >/dev/null
fi
