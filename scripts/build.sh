#!/bin/zsh

set -euo pipefail

root_dir="$(cd "$(dirname "$0")/.." && pwd)"
build_dir="$root_dir/build"
app_dir="$build_dir/Probo.app"
app_contents_dir="$app_dir/Contents"
app_binary_dir="$app_contents_dir/MacOS"
app_resources_dir="$app_contents_dir/Resources"
swift_dir="$root_dir/macos"
sdk_path="$(xcrun --sdk macosx --show-sdk-path)"
swift_target="$(uname -m)-apple-macos26.0"
swift_sources=()
signing_identity="${PROBO_CODESIGN_IDENTITY:-${PROBO_CODESIGN_DEFAULT_IDENTITY:-Probo Local Code Signing}}"

while IFS= read -r source; do
  swift_sources+=("$source")
done < <(find "$swift_dir/Sources" -type f -name '*.swift' | sort)

if [[ "$signing_identity" != "-" ]] && ! security find-identity -p codesigning | grep -qF "\"$signing_identity\""; then
  PROBO_CODESIGN_DEFAULT_IDENTITY="$signing_identity" "$root_dir/scripts/local/setup-codesign.sh" >/dev/null
fi

rm -rf "$app_dir"
mkdir -p "$app_binary_dir" "$app_resources_dir"

xcrun swiftc \
  -sdk "$sdk_path" \
  -target "$swift_target" \
  -swift-version 6 \
  -O \
  -framework AppKit \
  -framework ApplicationServices \
  -framework ServiceManagement \
  "${swift_sources[@]}" \
  -o "$app_binary_dir/Probo"

cp "$swift_dir/Resources/Info.plist" "$app_contents_dir/Info.plist"

codesign \
  --force \
  --options runtime \
  --sign "$signing_identity" \
  --timestamp=none \
  "$app_dir"
codesign --verify --deep --strict "$app_dir"
echo "signed $app_dir with $signing_identity"

echo "built $app_dir"
