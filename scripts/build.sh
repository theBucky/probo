#!/bin/zsh

set -euo pipefail

root_dir="$(cd "$(dirname "$0")/.." && pwd)"
build_dir="$root_dir/build"
rust_target_dir="$build_dir/rust"
app_dir="$build_dir/Probo.app"
app_contents_dir="$app_dir/Contents"
app_binary_dir="$app_contents_dir/MacOS"
app_resources_dir="$app_contents_dir/Resources"
runtime_dir="$root_dir/runtime"
swift_dir="$root_dir/macos"
sdk_path="$(xcrun --sdk macosx --show-sdk-path)"
swift_target="$(uname -m)-apple-macos26.0"
rust_lib_dir="$rust_target_dir/release"
swift_sources=("$swift_dir"/Sources/*.swift)
signing_identity="${PROBO_CODESIGN_IDENTITY:-${PROBO_CODESIGN_DEFAULT_IDENTITY:-Probo Local Code Signing}}"

if [[ "$signing_identity" != "-" ]] && ! security find-identity -p codesigning | grep -qF "\"$signing_identity\""; then
  PROBO_CODESIGN_DEFAULT_IDENTITY="$signing_identity" "$root_dir/scripts/setup-local-codesign.sh" >/dev/null
fi

rm -rf "$app_dir"
mkdir -p "$app_binary_dir" "$app_resources_dir"

cargo build \
  --manifest-path "$runtime_dir/Cargo.toml" \
  --release \
  --target-dir "$rust_target_dir"

xcrun swiftc \
  -sdk "$sdk_path" \
  -target "$swift_target" \
  -swift-version 6 \
  -O \
  -import-objc-header "$runtime_dir/include/probo_runtime.h" \
  -L "$rust_lib_dir" \
  -lprobo_runtime \
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
