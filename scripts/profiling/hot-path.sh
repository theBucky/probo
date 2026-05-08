#!/bin/zsh

set -euo pipefail

root_dir="$(cd "$(dirname "$0")/../.." && pwd)"
build_dir="$root_dir/build/hot-path"
probe_source="$root_dir/probo/Tools/HotPathProfile/HotPathProfile.swift"
probe_binary="$build_dir/HotPathProfile"
app_dir="$root_dir/build/Probo.app"
app_executable="$app_dir/Contents/MacOS/Probo"
profile_entitlements="$root_dir/probo/Tools/HotPathProfile/profile.entitlements"
swift_dir="$root_dir/probo"
sdk_path="$(xcrun --sdk macosx --show-sdk-path)"
swift_target="$(uname -m)-apple-macos26.0"
signing_identity="${PROBO_CODESIGN_IDENTITY:-${PROBO_CODESIGN_DEFAULT_IDENTITY:-Probo Local Code Signing}}"
record_kind="none"
trace_duration=15
post_events_seen=false
probe_args=()

take_option_value() {
  local name="$1"
  local value="${2:-}"
  if [[ -z "$value" ]]; then
    echo "missing value for $name" >&2
    exit 64
  fi
  printf "%s" "$value"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --record-app)
      record_kind="$(take_option_value "$1" "${2:-}")"
      shift 2
      ;;
    --trace-duration)
      trace_duration="$(take_option_value "$1" "${2:-}")"
      shift 2
      ;;
    --post-events)
      post_events_seen=true
      probe_args+=("$1" "$(take_option_value "$1" "${2:-}")")
      shift 2
      ;;
    *)
      probe_args+=("$1")
      shift
      ;;
  esac
done

mkdir -p "$build_dir"

xcrun swiftc \
  -sdk "$sdk_path" \
  -target "$swift_target" \
  -swift-version 6 \
  -O \
  -framework ApplicationServices \
  "$swift_dir/Sources/Core/ScrollIntensity.swift" \
  "$swift_dir/Sources/Core/ScrollRewriteCore.swift" \
  "$swift_dir/Sources/Configuration/AppConfiguration.swift" \
  "$swift_dir/Sources/Events/ScrollEventSynthesizer.swift" \
  "$probe_source" \
  -o "$probe_binary"

if [[ "$record_kind" == "none" ]]; then
  "$probe_binary" "${probe_args[@]}"
  exit 0
fi

case "$record_kind" in
  time)
    template="Time Profiler"
    ;;
  allocations)
    template="Allocations"
    ;;
  system)
    template="System Trace"
    ;;
  *)
    echo "unknown --record-app value: $record_kind" >&2
    echo "expected one of: time, allocations, system" >&2
    exit 2
    ;;
esac

if ! xcrun --find xctrace >/dev/null 2>&1; then
  echo "xctrace is unavailable; install/select full Xcode to use --record-app" >&2
  echo "micro profile still works without xctrace:" >&2
  echo "  scripts/profiling/hot-path.sh" >&2
  exit 127
fi

PROBO_CODESIGN_DEFAULT_IDENTITY="$signing_identity" "$root_dir/scripts/build.sh" >/dev/null
codesign \
  --force \
  --options runtime \
  --entitlements "$profile_entitlements" \
  --sign "$signing_identity" \
  --timestamp=none \
  "$app_dir" >/dev/null

if pgrep -f -x "$app_executable" >/dev/null; then
  pkill -f -x "$app_executable"
  while pgrep -f -x "$app_executable" >/dev/null; do
    sleep 0.1
  done
fi

env -i \
  HOME="$HOME" \
  LOGNAME="$LOGNAME" \
  PATH="/usr/bin:/bin:/usr/sbin:/sbin" \
  TMPDIR="${TMPDIR:-/tmp}" \
  USER="$USER" \
  open "$app_dir"

for _ in {1..50}; do
  pid="$(pgrep -f -x "$app_executable" | tail -n 1 || true)"
  [[ -n "$pid" ]] && break
  sleep 0.1
done

if [[ -z "${pid:-}" ]]; then
  echo "Probo did not start" >&2
  exit 1
fi

if [[ "$post_events_seen" == false ]]; then
  probe_args+=("--post-events" "$((trace_duration * 120))" "--post-interval-usec" "8333")
fi

timestamp="$(date +%Y%m%d-%H%M%S)"
trace_path="$build_dir/probo-$record_kind-$timestamp.trace"
log_path="$build_dir/probo-$record_kind-$timestamp.xctrace.log"

echo "recording $template for pid $pid"
echo "trace: $trace_path"
echo "log: $log_path"

xcrun xctrace record \
  --template "$template" \
  --attach "$pid" \
  --time-limit "${trace_duration}s" \
  --output "$trace_path" \
  >"$log_path" 2>&1 &
trace_pid=$!

sleep 2
"$probe_binary" "${probe_args[@]}"
wait "$trace_pid"

echo ""
echo "wrote $trace_path"
