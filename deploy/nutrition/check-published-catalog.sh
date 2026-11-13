#!/bin/sh
set -eu
script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$script_dir/common.sh"
require_command psql
connect_nutrition_database
psql -X -q -v ON_ERROR_STOP=1 -f "$script_dir/check-published-catalog.sql"
echo 'Published Nutrition catalog integrity and meal coverage passed.'
