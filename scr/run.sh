#!/bin/zsh

set -euo pipefail

root_dir="$(cd "$(dirname "$0")/.." && pwd)"

"$root_dir/scr/build.sh"
open "$root_dir/build/Probo.app"
