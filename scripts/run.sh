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

root_dir="$(cd "$(dirname "$0")/.." && pwd)"
source "$root_dir/scripts/lib.sh"

"$root_dir/scripts/build.sh"
stop_app
open "$app_dir"

if [[ "$mode" == "verify" ]]; then
  sleep 1
  pgrep -f -x "$app_executable" >/dev/null
  echo "Probo is running"
fi
