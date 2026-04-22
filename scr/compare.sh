#!/bin/zsh

set -euo pipefail

root_dir="$(cd "$(dirname "$0")/.." && pwd)"

cargo run \
  --manifest-path "$root_dir/scr/runtime/Cargo.toml" \
  --release \
  --bin probo_compare
