#!/bin/zsh

set -euo pipefail

root_dir="$(cd "$(dirname "$0")/.." && pwd)"
build_dir="$root_dir/build/tests"
swift_dir="$root_dir/probo"
sdk_path="$(xcrun --sdk macosx --show-sdk-path)"
swift_target="$(uname -m)-apple-macos15.0"
swift_sources=()
test_sources=()

for source_root in App Core Configuration Events System UI; do
  while IFS= read -r source; do
    [[ "$(basename "$source")" == "ProboApp.swift" ]] && continue
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
  -framework AppKit \
  -framework ApplicationServices \
  -framework IOKit \
  -framework ServiceManagement \
  "${swift_sources[@]}" \
  "${test_sources[@]}" \
  -o "$build_dir/ProboTests"

"$build_dir/ProboTests"
