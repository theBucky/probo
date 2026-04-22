#!/bin/zsh

set -euo pipefail

openssl_bin="/usr/bin/openssl"
identity_name="${PROBO_CODESIGN_DEFAULT_IDENTITY:-Probo Local Code Signing}"
certificate_org="${PROBO_CODESIGN_ORG:-Probo Local}"
certificate_days="${PROBO_CODESIGN_DAYS:-3650}"
keychain="${PROBO_CODESIGN_KEYCHAIN:-$(security default-keychain -d user | tr -d '"' | xargs)}"
force=0

usage() {
  echo "usage: $0 [--force]" >&2
}

find_identity() {
  security find-identity -v -p codesigning "$keychain" 2>/dev/null \
    | grep -F "\"$identity_name\"" \
    | sed -n 's/.*"\([^"]*\)".*/\1/p' \
    | head -n 1
}

for arg in "$@"; do
  case "$arg" in
    --force)
      force=1
      ;;
    *)
      usage
      exit 64
      ;;
  esac
done

if [[ $force -eq 1 ]]; then
  while security find-certificate -c "$identity_name" "$keychain" >/dev/null 2>&1; do
    security delete-certificate -c "$identity_name" "$keychain" >/dev/null
  done
fi

if [[ -n "$(find_identity)" ]]; then
  echo "installed $identity_name"
  echo "keychain $keychain"
  exit 0
fi

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
  -passout "pass:$identity_passphrase" >/dev/null 2>&1

security import \
  "$identity_file" \
  -k "$keychain" \
  -f pkcs12 \
  -P "$identity_passphrase" \
  -T /usr/bin/codesign \
  -T /usr/bin/security >/dev/null

if [[ -z "$(find_identity)" ]]; then
  security add-trusted-cert -p codeSign -k "$keychain" "$cert_file" >/dev/null
fi

if [[ -z "$(find_identity)" ]]; then
  echo "failed to install usable code-signing identity $identity_name" >&2
  exit 1
fi

echo "installed $identity_name"
echo "keychain $keychain"
