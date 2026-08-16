#!/bin/zsh

set -euo pipefail

mode="${1:-run}"
case "$mode" in
  run|verify) ;;
  *)
    echo "usage: $0 [run|verify]" >&2
    exit 64
    ;;
esac

root_dir="$(cd "$(dirname "$0")/../.." && pwd)"
signing_identity="${PROBO_CODESIGN_IDENTITY:-${PROBO_CODESIGN_DEFAULT_IDENTITY:-Probo Local Code Signing}}"
app_executable="$root_dir/build/Probo.app/Contents/MacOS/Probo"

PROBO_CODESIGN_DEFAULT_IDENTITY="$signing_identity" "$root_dir/scripts/build.sh"

if pgrep -f -x "$app_executable" >/dev/null; then
  pkill -f -x "$app_executable"
  while pgrep -f -x "$app_executable" >/dev/null; do
    sleep 0.1
  done
fi

open "$root_dir/build/Probo.app"

if [[ "$mode" == "verify" ]]; then
  sleep 1
  pgrep -f -x "$app_executable" >/dev/null
  echo "Probo is running"
fi
