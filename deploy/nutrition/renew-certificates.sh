#!/bin/sh
set -eu
script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$script_dir/common.sh"
. "$script_dir/certificates.sh"
require_command openssl
secret_dir=${1:-"$script_dir/../secrets/nutrition"}
[ -d "$secret_dir" ] || fail 'Nutrition secret directory is missing.'
secret_dir=$(CDPATH= cd -- "$secret_dir" && pwd)
for name in ca.pem ca-key.pem tls-password api.pfx nutrition.pfx; do
    [ -s "$secret_dir/$name" ] && [ -r "$secret_dir/$name" ] || fail 'An existing certificate/key/password file is missing or unreadable.'
done
openssl x509 -in "$secret_dir/ca.pem" -checkend 7776000 -noout >/dev/null || fail 'The CA expires within 90 days; plan CA replacement before issuing new leaf certificates.'
mkdir "$secret_dir/.prepare.lock" 2>/dev/null || fail 'Another certificate/secret operation is active.'
create_work_directory
cleanup() { cleanup_work_directory; rmdir "$secret_dir/.prepare.lock"; }
trap cleanup EXIT
trap 'exit 1' HUP INT TERM
cp "$secret_dir/ca.pem" "$work_dir/ca.pem"
cp "$secret_dir/ca-key.pem" "$work_dir/ca-key.pem"
cp "$secret_dir/tls-password" "$work_dir/tls-password"
(
    cd "$work_dir"
    issue_leaf_certificates
)
# Both bundles are complete before changing either file. Containers must be recreated to remount them.
for name in api nutrition; do
    cp "$work_dir/$name.pfx" "$secret_dir/$name.pfx.next"
    chmod 444 "$secret_dir/$name.pfx.next"
done
for name in api nutrition; do
    # Windows native rehearsals also need the old file's read-only attribute removed before rename.
    chmod 600 "$secret_dir/$name.pfx"
    mv -- "$secret_dir/$name.pfx.next" "$secret_dir/$name.pfx"
done
echo 'Internal leaf certificates renewed. Recreate API and Nutrition containers to load them.'
