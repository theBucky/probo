#!/bin/zsh

set -euo pipefail

root_dir="$(cd "$(dirname "$0")/.." && pwd)"
build_dir="$root_dir/build"
app_dir="$build_dir/Probo.app"
app_contents_dir="$app_dir/Contents"
app_binary_dir="$app_contents_dir/MacOS"
app_resources_dir="$app_contents_dir/Resources"
resource_dir="$root_dir/Sources/Probo/Resources"
signing_identity="${PROBO_CODESIGN_IDENTITY:-${PROBO_CODESIGN_DEFAULT_IDENTITY:-Probo Local Code Signing}}"

if [[ "$signing_identity" != "-" ]] && ! security find-identity -p codesigning | grep -qF "\"$signing_identity\""; then
  PROBO_CODESIGN_DEFAULT_IDENTITY="$signing_identity" "$root_dir/scripts/dev/setup-codesign.sh" >/dev/null
fi

cd "$root_dir"
swift build -c release --arch arm64 --product Probo
swift_bin_dir="$(swift build -c release --arch arm64 --show-bin-path)"

rm -rf "$app_dir"
mkdir -p "$app_binary_dir" "$app_resources_dir"
cp "$swift_bin_dir/Probo" "$app_binary_dir/Probo"
cp "$resource_dir/Info.plist" "$app_contents_dir/Info.plist"
cp "$resource_dir/AppIcon.icns" "$app_resources_dir/AppIcon.icns"

codesign \
  --force \
  --options runtime \
  --sign "$signing_identity" \
  --timestamp=none \
  "$app_dir"
codesign --verify --deep --strict "$app_dir"
echo "signed $app_dir with $signing_identity"

echo "built $app_dir"
