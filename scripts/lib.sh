# Sourced by every script. Expects root_dir to be set by the caller.

# Pins the toolchain per invocation without touching global xcode-select; machines without
# Xcode-beta fall through to the system default.
if [[ -n "${PROBO_DEVELOPER_DIR:-}" ]]; then
  export DEVELOPER_DIR="$PROBO_DEVELOPER_DIR"
elif [[ -d "/Applications/Xcode-beta.app/Contents/Developer" ]]; then
  export DEVELOPER_DIR="/Applications/Xcode-beta.app/Contents/Developer"
fi

signing_identity="${PROBO_CODESIGN_IDENTITY:-${PROBO_CODESIGN_DEFAULT_IDENTITY:-Probo Local Code Signing}}"
app_dir="$root_dir/build/Probo.app"
app_executable="$app_dir/Contents/MacOS/Probo"

# mint_identity <name> <org> <days> <dir>: writes dir/cert.pem and dir/identity.p12, prints the p12 passphrase.
mint_identity() {
  local identity_name="$1" certificate_org="$2" certificate_days="$3" dir="$4"
  local key_file="$dir/key.pem" cert_file="$dir/cert.pem" identity_file="$dir/identity.p12"
  local identity_passphrase
  identity_passphrase="$(/usr/bin/openssl rand -hex 16)"

  /usr/bin/openssl req \
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

  /usr/bin/openssl pkcs12 \
    -export \
    -inkey "$key_file" \
    -in "$cert_file" \
    -name "$identity_name" \
    -out "$identity_file" \
    -passout "pass:$identity_passphrase" >/dev/null 2>&1

  printf "%s" "$identity_passphrase"
}

stop_app() {
  if pgrep -f -x "$app_executable" >/dev/null; then
    pkill -f -x "$app_executable"
    while pgrep -f -x "$app_executable" >/dev/null; do
      sleep 0.1
    done
  fi
}
