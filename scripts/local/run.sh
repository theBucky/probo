#!/bin/zsh

set -euo pipefail

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
