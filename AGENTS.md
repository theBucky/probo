# Probo

menubar macOS app remapping mouse-wheel ticks to fixed line steps. swift/appkit shell over a rust `staticlib` core through a C FFI.

## Layout

- [macos/Sources/](macos/Sources): appkit shell, no SwiftPM; status menu, event tap, synth, config store, permission and launch-at-login glue
- [macos/Sources/RuntimeBridge.swift](macos/Sources/RuntimeBridge.swift): hand-mirrored C FFI, pairs with [probo_runtime.h](runtime/include/probo_runtime.h)
- [macos/Resources/Info.plist](macos/Resources/Info.plist): bundle plist
- [runtime/src/lib.rs](runtime/src/lib.rs): FFI surface and tap logic, the only entry swift calls
- [runtime/src/sim.rs](runtime/src/sim.rs): pure wheel simulator, where step maths live
- [runtime/src/bin/](runtime/src/bin): `probo_bench` for hot-path cost, `probo_compare` for immediate vs frame-aligned output
- [scripts/build.sh](scripts/build.sh): single source of truth for rust build, swift link, codesign; CI calls the same script
- [scripts/local/](scripts/local) and [scripts/ci/](scripts/ci): `run.sh`, `bench.sh`, `compare.sh`, codesign mint helpers

## Validate

- rust: `cargo fmt`, `cargo clippy --all-targets -- -D warnings`, `cargo test --release --manifest-path runtime/Cargo.toml`
- swift or FFI: `scripts/build.sh`

## Invariants

- FFI structs in [lib.rs](runtime/src/lib.rs), [probo_runtime.h](runtime/include/probo_runtime.h), [RuntimeBridge.swift](macos/Sources/RuntimeBridge.swift) move together
- `swiftc` flags in [build.sh](scripts/build.sh) are the only swift gate; target `macos26.0`, `-swift-version 6 -O`
- tap callback is hot; swift side stays allocation-free, logic lives in rust
- `should_passthrough` drops continuous, phased, diagonal, zero-delta events; extend, never loosen
- no rejects smoothing, momentum, acceleration, gesture-phase output, per-app rules

## Local

- [refs/](refs) is read-only inspiration; never edit or vendor from it
