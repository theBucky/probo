#!/bin/zsh

set -euo pipefail

root_dir="$(cd "$(dirname "$0")/.." && pwd)"
source "$root_dir/scripts/toolchain.sh"

build_dir="$root_dir/build"
app_dir="$build_dir/Probo.app"
app_contents_dir="$app_dir/Contents"
app_binary_dir="$app_contents_dir/MacOS"
app_resources_dir="$app_contents_dir/Resources"
resource_dir="$root_dir/Sources/Probo/Resources"
signing_identity="${PROBO_CODESIGN_IDENTITY:-${PROBO_CODESIGN_DEFAULT_IDENTITY:-Probo Local Code Signing}}"

min_system_version="$(plutil -extract LSMinimumSystemVersion raw "$resource_dir/Info.plist")"
sdk_version="$(xcrun --sdk macosx --show-sdk-version)"

if [[ "$signing_identity" != "-" ]] && ! security find-identity -p codesigning | grep -qF "\"$signing_identity\""; then
  PROBO_CODESIGN_DEFAULT_IDENTITY="$signing_identity" "$root_dir/scripts/dev/setup-codesign.sh" >/dev/null
fi

cd "$root_dir"
# Explicit platform_version keeps the recorded SDK in sync with the toolchain;
# the SwiftPM link step otherwise records the deployment target as the SDK.
swift build -c release --arch arm64 --product Probo \
  -Xlinker -platform_version -Xlinker macos \
  -Xlinker "$min_system_version" -Xlinker "$sdk_version"
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

build_info="$(xcrun vtool -show-build "$app_binary_dir/Probo")"
recorded_minos="$(awk '$1 == "minos" { print $2 }' <<<"$build_info")"
recorded_sdk="$(awk '$1 == "sdk" { print $2 }' <<<"$build_info")"
if [[ "$recorded_minos" != "$min_system_version" || "$recorded_sdk" != "$sdk_version" ]]; then
  echo "binary records minos $recorded_minos sdk $recorded_sdk, expected minos $min_system_version sdk $sdk_version" >&2
  exit 1
fi

echo "signed $app_dir with $signing_identity"
echo "built $app_dir (minos $recorded_minos, sdk $recorded_sdk)"
