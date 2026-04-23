#!/bin/zsh

set -euo pipefail

root_dir="$(cd "$(dirname "$0")/../.." && pwd)"

cargo run \
  --manifest-path "$root_dir/runtime/Cargo.toml" \
  --release \
  --features sim \
  --bin probo_compare
