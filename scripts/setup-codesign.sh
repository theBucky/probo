#!/bin/zsh

set -euo pipefail

root_dir="$(cd "$(dirname "$0")/.." && pwd)"
source "$root_dir/scripts/lib.sh"

identity_name="${PROBO_CODESIGN_DEFAULT_IDENTITY:-Probo Local Code Signing}"
certificate_org="${PROBO_CODESIGN_ORG:-Probo Local}"
certificate_days="${PROBO_CODESIGN_DAYS:-3650}"
keychain="${PROBO_CODESIGN_KEYCHAIN:-$(security default-keychain -d user | tr -d '"' | xargs)}"
force=0

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
      echo "usage: $0 [--force]" >&2
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

if security find-certificate -c "$identity_name" "$keychain" >/dev/null 2>&1; then
  echo "certificate $identity_name exists without a usable private key; rerun with --force" >&2
  exit 1
fi

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

identity_passphrase="$(mint_identity "$identity_name" "$certificate_org" "$certificate_days" "$tmp_dir")"

security import \
  "$tmp_dir/identity.p12" \
  -k "$keychain" \
  -f pkcs12 \
  -P "$identity_passphrase" \
  -T /usr/bin/codesign \
  -T /usr/bin/security >/dev/null

if [[ -z "$(find_identity)" ]]; then
  security add-trusted-cert -p codeSign -k "$keychain" "$tmp_dir/cert.pem" >/dev/null
fi

if [[ -z "$(find_identity)" ]]; then
  echo "failed to install usable code-signing identity $identity_name" >&2
  exit 1
fi

echo "installed $identity_name"
echo "keychain $keychain"
