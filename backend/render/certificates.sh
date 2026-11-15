#!/bin/bash
set -euo pipefail

# Generated at container start; private keys never enter the image or repository.
issue_loopback_certificate() {
    local runtime_dir=${1:?Pass the protected runtime directory}
    openssl req -x509 -newkey rsa:2048 -nodes -sha256 -days 365 \
        -subj '/CN=CareSitter container CA' \
        -addext 'basicConstraints=critical,CA:TRUE' \
        -addext 'keyUsage=critical,keyCertSign,cRLSign' \
        -keyout "$runtime_dir/ca.key" -out "$runtime_dir/ca.pem" 2>/dev/null
    openssl req -new -newkey rsa:2048 -nodes -subj '/CN=localhost' \
        -keyout "$runtime_dir/localhost.key" -out "$runtime_dir/localhost.csr" 2>/dev/null
    printf '%s\n' 'basicConstraints=critical,CA:FALSE' \
        'keyUsage=critical,digitalSignature,keyEncipherment' 'extendedKeyUsage=serverAuth' \
        'subjectAltName=DNS:localhost,IP:127.0.0.1' > "$runtime_dir/localhost.ext"
    openssl x509 -req -in "$runtime_dir/localhost.csr" \
        -CA "$runtime_dir/ca.pem" -CAkey "$runtime_dir/ca.key" \
        -set_serial "0x$(openssl rand -hex 16)" -days 365 -sha256 \
        -extfile "$runtime_dir/localhost.ext" -out "$runtime_dir/localhost.pem" 2>/dev/null
    openssl pkcs12 -export -inkey "$runtime_dir/localhost.key" \
        -in "$runtime_dir/localhost.pem" -certfile "$runtime_dir/ca.pem" \
        -out "$runtime_dir/localhost.pfx" -passout env:container_tls_password
    rm "$runtime_dir/ca.key" "$runtime_dir/localhost.key" "$runtime_dir/localhost.csr"
}
