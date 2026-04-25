#!/bin/zsh

set -euo pipefail

root_dir="$(cd "$(dirname "$0")/.." && pwd)"
swift_dir="$root_dir/probo"
sdk_path="$(xcrun --sdk macosx --show-sdk-path)"
swift_target="$(uname -m)-apple-macos26.0"
output_path="$root_dir/compile_commands.json"

json_escape() {
  local value="$1"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  value="${value//$'\n'/\\n}"
  printf "%s" "$value"
}

json_string() {
  printf "\""
  json_escape "$1"
  printf "\""
}

write_argument_array() {
  local arguments=("$@")
  local index=1

  printf "["
  for argument in "${arguments[@]}"; do
    if (( index > 1 )); then
      printf ", "
    fi

    json_string "$argument"
    (( index += 1 ))
  done
  printf "]"
}

write_entry() {
  local primary_file="$1"
  local module_name="$2"
  local arguments=(
    "xcrun"
    "swiftc"
    "-sdk"
    "$sdk_path"
    "-target"
    "$swift_target"
    "-swift-version"
    "6"
    "-O"
    "-module-name"
    "$module_name"
    "-c"
  )

  for framework in "${current_frameworks[@]}"; do
    arguments+=("-framework" "$framework")
  done

  for source in "${current_sources[@]}"; do
    arguments+=("$source")
  done

  if (( entries_written > 0 )); then
    printf ",\n"
  fi

  printf "  { \"directory\": "
  json_string "$root_dir"
  printf ", \"file\": "
  json_string "$primary_file"
  printf ", \"arguments\": "
  write_argument_array "${arguments[@]}"
  printf " }"

  (( entries_written += 1 ))
}

app_sources=()
while IFS= read -r source; do
  app_sources+=("$source")
done < <(find "$swift_dir/Sources" -type f -name "*.swift" | sort)

test_sources=(
  "$swift_dir/Sources/Events/ScrollEventSynthesizer.swift"
)
test_primary_sources=()

for source_root in Core Configuration; do
  while IFS= read -r source; do
    test_sources+=("$source")
  done < <(find "$swift_dir/Sources/$source_root" -type f -name "*.swift" | sort)
done

while IFS= read -r source; do
  test_sources+=("$source")
  test_primary_sources+=("$source")
done < <(find "$swift_dir/Tests" -type f -name "*.swift" | sort)

entries_written=0
{
  printf "[\n"

  current_sources=("${app_sources[@]}")
  current_frameworks=(AppKit ApplicationServices ServiceManagement)
  for source in "${app_sources[@]}"; do
    write_entry "$source" "Probo"
  done

  current_sources=("${test_sources[@]}")
  current_frameworks=(ApplicationServices)
  for source in "${test_primary_sources[@]}"; do
    write_entry "$source" "ProboTests"
  done

  printf "\n]\n"
} > "$output_path"

echo "wrote $output_path"
