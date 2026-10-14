#!/bin/sh
set -eu
script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$script_dir/common.sh"
for command in pg_dump pg_restore age sha256sum; do require_command "$command"; done
connect_nutrition_database
backup_dir=${BACKUP_DIRECTORY:?Set BACKUP_DIRECTORY}
recipient_file=${BACKUP_RECIPIENT_FILE:?Set BACKUP_RECIPIENT_FILE}
read_secret "$recipient_file" >/dev/null
mkdir -p -- "$backup_dir"
chmod 700 "$backup_dir"
create_work_directory
partial=''
cleanup() { [ -z "$partial" ] || rm -f -- "$partial"; cleanup_work_directory; }
trap cleanup EXIT
trap 'exit 1' HUP INT TERM
pg_dump --format=custom --file="$work_dir/nutrition.dump"
pg_restore --list "$work_dir/nutrition.dump" > "$work_dir/dump-list"
partial=$(mktemp "$backup_dir/nutrition-$(date -u +%Y%m%dT%H%M%SZ)-XXXXXXXX.dump.age.partial")
age -R "$recipient_file" -o "$partial" "$work_dir/nutrition.dump"
final=${partial%.partial}
mv -- "$partial" "$final"
partial=''
(cd "$backup_dir" && sha256sum "${final##*/}" > "${final##*/}.sha256")
echo "Encrypted nutrition backup created: ${final##*/}"
