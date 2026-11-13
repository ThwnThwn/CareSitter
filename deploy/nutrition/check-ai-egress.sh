#!/bin/sh
# Run inside the running Nutrition container, using its effective feature flags.
set -eu
probe_provider() {
    case "$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')" in true) ;; *) return 0 ;; esac
    # Use only the authority: never send configured paths, queries, keys or health data.
    case "$2" in https://*) ;; *) echo 'AI egress check requires HTTPS.' >&2; exit 1 ;; esac
    authority=${2#https://}
    authority=${authority%%/*}
    printf '%s\n' "$authority" | grep -Eq '^[A-Za-z0-9][A-Za-z0-9.-]*(:[0-9]{1,5})?$' || {
        echo 'AI egress check rejected an invalid provider authority.' >&2; exit 1;
    }
    # Ignore HTTP status (401/403 are expected without a key); verify DNS/TCP/TLS.
    # Disable proxies and curl config so this checks this container's direct route.
    if ! curl -q --noproxy '*' --proto '=https' --head --silent \
        --connect-timeout 5 --max-time 10 --output /dev/null "https://$authority/" 2>/dev/null; then
        echo 'AI unreachable: DNS/TLS probe failed; AI requests may use fallback. No payload was sent.' >&2
        exit 1
    fi
    echo 'PASS: enabled AI provider DNS/TLS reachable (no credentials or health payload sent).'
}
probe_provider "${HealthParser__Enabled:-false}" "${HealthParser__BaseUrl:-https://api.openai.com/v1/}"
probe_provider "${MealRanking__Enabled:-false}" "${MealRanking__BaseUrl:-https://generativelanguage.googleapis.com/v1beta/}"
