#!/bin/zsh

set -euo pipefail

root_dir="$(cd "$(dirname "$0")/.." && pwd)"
source "$root_dir/scripts/lib.sh"

identity_name="${PROBO_RELEASE_IDENTITY:-Probo Release Code Signing}"
certificate_org="${PROBO_CODESIGN_ORG:-Probo Release}"
certificate_days="${PROBO_CODESIGN_DAYS:-3650}"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

identity_passphrase="$(mint_identity "$identity_name" "$certificate_org" "$certificate_days" "$tmp_dir")"

cat <<EOF
add these as repo secrets (Settings > Secrets and variables > Actions):

PROBO_RELEASE_P12_PASSWORD
$identity_passphrase

PROBO_RELEASE_P12_BASE64
$(base64 < "$tmp_dir/identity.p12")
EOF
