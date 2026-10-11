#!/bin/sh
set -eu
psql --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" --set ON_ERROR_STOP=1 \
  --set "app_password=$NUTRITION_DB_APP_PASSWORD" --file /runtime-role.sql
