#!/bin/sh
set -eu
script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$script_dir/common.sh"
. "$script_dir/certificates.sh"
require_command openssl
require_command age-keygen
secret_dir=${1:-"$script_dir/../secrets/nutrition"}
recovery_dir=${2:-"$script_dir/../secrets/nutrition-recovery"}
mkdir -p -- "$secret_dir" "$recovery_dir"
chmod 700 "$secret_dir" "$recovery_dir"
secret_dir=$(CDPATH= cd -- "$secret_dir" && pwd)
recovery_dir=$(CDPATH= cd -- "$recovery_dir" && pwd)
mkdir "$secret_dir/.prepare.lock" 2>/dev/null || fail 'Another preparation is active; verify it before removing its lock.'
create_work_directory
cleanup() { cleanup_work_directory; rmdir "$secret_dir/.prepare.lock"; }
trap cleanup EXIT
trap 'exit 1' HUP INT TERM

if [ -e "$secret_dir/api.pfx" ] || [ -e "$secret_dir/nutrition.pfx" ]; then
    [ -e "$secret_dir/tls-password" ] || fail 'TLS certificates exist without their password; do not generate a replacement password.'
fi
for name in db-admin-password db-app-password gateway-key people-key tls-password; do
    if [ ! -e "$secret_dir/$name" ]; then
        openssl rand -hex 32 > "$secret_dir/$name"
    fi
    read_secret "$secret_dir/$name" >/dev/null
done

existing=0
for name in ca.pem ca-key.pem api.pfx nutrition.pfx; do
    [ ! -e "$secret_dir/$name" ] || existing=$((existing+1))
done
case "$existing" in
    0)
        cp "$secret_dir/tls-password" "$work_dir/tls-password"
        (
            cd "$work_dir"
            # An explicit config prevents duplicate CA extensions from machine OpenSSL defaults.
            cat > ca.request.cnf <<'EOF'
[req]
distinguished_name=dn
x509_extensions=ca
prompt=no
[dn]
CN=CareSitter Internal Nutrition CA
[ca]
basicConstraints=critical,CA:TRUE,pathlen:0
keyUsage=critical,keyCertSign,cRLSign
subjectKeyIdentifier=hash
authorityKeyIdentifier=keyid:always
EOF
            openssl req -x509 -newkey rsa:3072 -nodes -keyout ca-key.pem -out ca.pem \
                -days 730 -sha256 -config ca.request.cnf 2>/dev/null
            issue_leaf_certificates
        )
        for name in ca.pem ca-key.pem api.pfx nutrition.pfx; do cp "$work_dir/$name" "$secret_dir/$name"; done
        ;;
    4) ;;
    *) fail 'Incomplete internal TLS files; inspect them before any certificate change.' ;;
esac

if [ ! -e "$recovery_dir/age-identity" ]; then
    [ ! -e "$secret_dir/backup-recipient" ] || fail 'Backup recipient exists without its recovery identity; do not replace it.'
    age-keygen -o "$recovery_dir/age-identity" 2>/dev/null
fi
age-keygen -y "$recovery_dir/age-identity" > "$work_dir/backup-recipient"
if [ -e "$secret_dir/backup-recipient" ]; then
    cmp -s "$secret_dir/backup-recipient" "$work_dir/backup-recipient" || fail 'Backup recipient and recovery identity do not match.'
else
    cp "$work_dir/backup-recipient" "$secret_dir/backup-recipient"
fi
chmod 600 "$secret_dir/ca-key.pem" "$recovery_dir/age-identity"
# Compose file secrets are bind mounts: host parent 0700 protects these files while APP_UID can read the mounts.
for name in db-admin-password db-app-password gateway-key people-key tls-password ca.pem api.pfx nutrition.pfx backup-recipient; do
    chmod 444 "$secret_dir/$name"
done
if [ -e "$secret_dir/gemini-api-key" ]; then
    read_secret "$secret_dir/gemini-api-key" >/dev/null
    chmod 444 "$secret_dir/gemini-api-key"
fi
echo 'Nutrition secrets prepared. Existing credentials and certificates were preserved.'
