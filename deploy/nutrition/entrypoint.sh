#!/bin/sh
set -eu

read_secret() {
    [ -s "/run/secrets/$1" ] || { echo "Missing Nutrition secret: $1" >&2; exit 1; }
    cat "/run/secrets/$1"
}

case "${1:-}" in
    api)
        export NutritionGateway__ServiceKey="$(read_secret nutrition_gateway_key)"
        export NutritionIntegration__ServiceKey="$(read_secret nutrition_people_key)"
        export Kestrel__Endpoints__Internal__Certificate__Password="$(read_secret tls_password)"
        exec dotnet CareSitter.ApiHost.dll
        ;;
    nutrition)
        password="$(read_secret nutrition_db_app)"
        export ConnectionStrings__Nutrition="Host=nutrition-db;Database=nutrition;Username=nutrition_app;Password=$password"
        export Gateway__ServiceKey="$(read_secret nutrition_gateway_key)"
        export People__ServiceKey="$(read_secret nutrition_people_key)"
        export Kestrel__Endpoints__Grpc__Certificate__Password="$(read_secret tls_password)"
        exec dotnet CareSitter.Nutrition.dll
        ;;
    *) echo 'Expected api or nutrition.' >&2; exit 1 ;;
esac
