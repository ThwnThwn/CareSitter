#!/bin/sh
set -eu
umask 077
[ -s /run/secrets/nutrition_catalog_connection ] || {
    echo 'Provide the connection secret for the current catalog role.' >&2; exit 1;
}
export NUTRITION_CATALOG_CONNECTION="$(cat /run/secrets/nutrition_catalog_connection)"
exec dotnet CareSitter.Nutrition.CatalogTool.dll "$@"
