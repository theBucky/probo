#!/bin/zsh

set -euo pipefail

openssl_bin="/usr/bin/openssl"
identity_name="${PROBO_RELEASE_IDENTITY:-Probo Release Code Signing}"
certificate_org="${PROBO_CODESIGN_ORG:-Probo Release}"
certificate_days="${PROBO_CODESIGN_DAYS:-3650}"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

key_file="$tmp_dir/key.pem"
cert_file="$tmp_dir/cert.pem"
identity_file="$tmp_dir/identity.p12"
identity_passphrase="$("$openssl_bin" rand -hex 16)"

"$openssl_bin" req \
  -newkey rsa:2048 \
  -x509 \
  -sha256 \
  -days "$certificate_days" \
  -nodes \
  -keyout "$key_file" \
  -out "$cert_file" \
  -subj "/CN=$identity_name/O=$certificate_org/" \
  -addext "basicConstraints=critical,CA:FALSE" \
  -addext "keyUsage=critical,digitalSignature" \
  -addext "extendedKeyUsage=codeSigning" >/dev/null 2>&1

"$openssl_bin" pkcs12 \
  -export \
  -inkey "$key_file" \
  -in "$cert_file" \
  -name "$identity_name" \
  -out "$identity_file" \
  -passout "pass:$identity_passphrase" >/dev/null

cat <<EOF
add these as repo secrets (Settings > Secrets and variables > Actions):

PROBO_RELEASE_P12_PASSWORD
$identity_passphrase

PROBO_RELEASE_P12_BASE64
$(base64 < "$identity_file")
EOF
