#!/bin/zsh

set -euo pipefail

root_dir="$(cd "$(dirname "$0")/.." && pwd)"
build_dir="$root_dir/build/tests"
swift_dir="$root_dir/probo"
sdk_path="$(xcrun --sdk macosx --show-sdk-path)"
swift_target="$(uname -m)-apple-macos26.0"
swift_sources=(
  "$swift_dir/Sources/Events/ScrollEventSynthesizer.swift"
)
test_sources=()

for source_root in Core Configuration; do
  while IFS= read -r source; do
    swift_sources+=("$source")
  done < <(find "$swift_dir/Sources/$source_root" -type f -name '*.swift' | sort)
done

while IFS= read -r source; do
  test_sources+=("$source")
done < <(find "$swift_dir/Tests" -type f -name '*.swift' | sort)

mkdir -p "$build_dir"

xcrun swiftc \
  -sdk "$sdk_path" \
  -target "$swift_target" \
  -swift-version 6 \
  -O \
  -framework ApplicationServices \
  "${swift_sources[@]}" \
  "${test_sources[@]}" \
  -o "$build_dir/ProboTests"

"$build_dir/ProboTests"
