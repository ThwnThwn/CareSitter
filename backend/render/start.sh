#!/bin/bash
set -euo pipefail
umask 077

public_port=${PORT:-8080}
[[ "$public_port" =~ ^[0-9]+$ ]] && ((public_port >= 1024 && public_port <= 65535)) \
    && [[ "$public_port" != 8443 && "$public_port" != 8444 && "$public_port" != 8081 ]] \
    || { echo 'PORT must be an unprivileged port outside the internal port range.' >&2; exit 1; }
case "${RENDER_NUTRITION_ENABLED:-false}" in
    true|false) ;;
    *) echo 'RENDER_NUTRITION_ENABLED must be true or false.' >&2; exit 1 ;;
esac

# Endpoint configuration belongs to this launcher, separately for each process.
while IFS= read -r name; do unset "$name"; done < <(compgen -v Kestrel__ || true)
unset ASPNETCORE_URLS ASPNETCORE_HTTP_PORTS ASPNETCORE_HTTPS_PORTS

runtime_dir=$(mktemp -d /tmp/caresitter-render.XXXXXXXX)
children=()
cleanup() {
    trap '' TERM INT
    if ((${#children[@]})); then
        kill -TERM "${children[@]}" 2>/dev/null || true
        # Bound shutdown, then reap every child before deleting certificate material.
        (sleep 20; kill -KILL "${children[@]}" 2>/dev/null || true) &
        local watchdog=$!
        for child in "${children[@]}"; do wait "$child" 2>/dev/null || true; done
        kill "$watchdog" 2>/dev/null || true
        wait "$watchdog" 2>/dev/null || true
    fi
    rm -f /tmp/caresitter-render-ca.path
    rm -rf -- "$runtime_dir"
}
trap cleanup EXIT
trap 'exit 143' TERM
trap 'exit 130' INT

export Kestrel__Endpoints__Http__Url="http://0.0.0.0:$public_port"
export Kestrel__Endpoints__Http__Protocols=Http1
export NutritionGateway__Enabled=false
if [[ "${RENDER_NUTRITION_ENABLED:-false}" == true ]]; then
    [[ -n "${ConnectionStrings__Nutrition:-}" ]] \
        || { echo 'ConnectionStrings__Nutrition is required.' >&2; exit 1; }
    export container_tls_password
    container_tls_password=$(openssl rand -hex 32)
    source /app/render/certificates.sh
    issue_loopback_certificate "$runtime_dir"
    printf '%s\n' "$runtime_dir/ca.pem" > /tmp/caresitter-render-ca.path
    export NutritionGateway__Enabled=true
    export NutritionGateway__GrpcUrl=https://localhost:8444/
    export NutritionGateway__TrustedRootCertificatePath="$runtime_dir/ca.pem"
    export NutritionGateway__ServiceKey="${NutritionGateway__ServiceKey:-$(openssl rand -hex 32)}"
    export NutritionIntegration__ServiceKey="${NutritionIntegration__ServiceKey:-$(openssl rand -hex 32)}"
    export Kestrel__Endpoints__Internal__Url=https://127.0.0.1:8443
    export Kestrel__Endpoints__Internal__Protocols=Http1
    export Kestrel__Endpoints__Internal__Certificate__Path="$runtime_dir/localhost.pfx"
    export Kestrel__Endpoints__Internal__Certificate__Password="$container_tls_password"
    (
        cd /app/nutrition
        unset Kestrel__Endpoints__Internal__Url Kestrel__Endpoints__Internal__Protocols
        unset Kestrel__Endpoints__Internal__Certificate__Path Kestrel__Endpoints__Internal__Certificate__Password
        export Kestrel__Endpoints__Http__Url=http://127.0.0.1:8081
        export Kestrel__Endpoints__Grpc__Url=https://127.0.0.1:8444
        export Kestrel__Endpoints__Grpc__Protocols=Http2
        export Kestrel__Endpoints__Grpc__Certificate__Path="$runtime_dir/localhost.pfx"
        export Kestrel__Endpoints__Grpc__Certificate__Password="$container_tls_password"
        export Gateway__ServiceKey="$NutritionGateway__ServiceKey"
        export People__BaseUrl=https://localhost:8443/
        export People__ServiceKey="$NutritionIntegration__ServiceKey"
        export People__TrustedRootCertificatePath="$runtime_dir/ca.pem"
        exec dotnet CareSitter.Nutrition.dll
    ) &
    children+=("$!")
fi
unset container_tls_password
cd /app/api
dotnet CareSitter.ApiHost.dll &
children+=("$!")
set +e
wait -n "${children[@]}"
status=$?
set -e
echo 'A backend process stopped; shutting down the service.' >&2
((status == 0)) && status=1
exit "$status"
