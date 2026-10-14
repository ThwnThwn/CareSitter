#!/bin/sh
# Caller enters its protected work directory with ca.pem, ca-key.pem and tls-password.
issue_leaf_certificates() {
    run_openssl() { MSYS2_ARG_CONV_EXCL='*' openssl "$@"; }
    for name in api nutrition; do
        cat > "$name.request.cnf" <<EOF
[req]
distinguished_name=dn
prompt=no
[dn]
CN=$name
EOF
        run_openssl req -new -newkey rsa:2048 -nodes -keyout "$name.key" -out "$name.csr" -config "$name.request.cnf" 2>/dev/null
        printf '%s\n' 'basicConstraints=critical,CA:FALSE' 'keyUsage=critical,digitalSignature,keyEncipherment' \
            'extendedKeyUsage=serverAuth' 'subjectKeyIdentifier=hash' 'authorityKeyIdentifier=keyid,issuer' \
            "subjectAltName=DNS:$name" > "$name.ext"
        run_openssl x509 -req -in "$name.csr" -CA ca.pem -CAkey ca-key.pem -set_serial "0x$(openssl rand -hex 16)" \
            -out "$name.pem" -days 90 -sha256 -extfile "$name.ext" 2>/dev/null
        run_openssl verify -purpose sslserver -verify_hostname "$name" -CAfile ca.pem "$name.pem" >/dev/null
        run_openssl pkcs12 -export -out "$name.pfx" -inkey "$name.key" -in "$name.pem" -certfile ca.pem -passout file:tls-password
    done
}
