# Probo

Menubar macOS app that remaps mouse wheel ticks to fixed line steps. Swift/AppKit shell over a Rust `staticlib` core via C FFI.

## Shell

Swift/AppKit at [macos/](macos), no SwiftPM.

- [Sources/](macos/Sources): AppDelegate, StatusMenuController, EventTapController, ScrollEventSynthesizer, AppConfiguration(Store), AccessibilityPermission, LaunchAtLoginManager
- [RuntimeBridge.swift](macos/Sources/RuntimeBridge.swift): mirrors the C FFI header
- [Resources/Info.plist](macos/Resources/Info.plist): bundle plist

## Core

Rust `staticlib` at [runtime/](runtime).

- [src/lib.rs](runtime/src/lib.rs): FFI surface and tap logic
- [src/sim.rs](runtime/src/sim.rs): wheel simulator
- [src/bin/](runtime/src/bin): `probo_bench`, `probo_compare`
- [include/probo_runtime.h](runtime/include/probo_runtime.h): C header

## Scripts

At [scripts/](scripts), shell-only, no build system.

- [build.sh](scripts/build.sh): rebuild Rust lib, link Swift, codesign bundle
- [run.sh](scripts/run.sh): build then relaunch `Probo.app`
- [bench.sh](scripts/bench.sh): hot-path cost, optional iteration count
- [compare.sh](scripts/compare.sh): immediate vs frame-aligned output
- [setup-local-codesign.sh](scripts/setup-local-codesign.sh): mint local signing identity

## Validate

- Rust: `cargo fmt`, `cargo clippy --all-targets -- -D warnings`, `cargo test --release` with `--manifest-path runtime/Cargo.toml`
- Swift or FFI: `scripts/build.sh`

## Invariants

- FFI structs in `runtime/src/lib.rs`, `runtime/include/probo_runtime.h`, `macos/Sources/RuntimeBridge.swift` must move together
- `swiftc` flags in `scripts/build.sh` are the only Swift gate; target `macos26.0`, `-swift-version 6 -O`
- tap callback runs hot; keep Swift side allocation-free, push logic into Rust
- `should_passthrough` drops continuous, phased, diagonal, zero-delta events; extend, do not loosen
- v1 rejects smoothing, momentum, acceleration, gesture-phase output, per-app rules

## Local

- codesign identity minted by [setup-local-codesign.sh](scripts/setup-local-codesign.sh); override with `PROBO_CODESIGN_IDENTITY`
- [refs/](refs) is read-only inspiration; never edit or vendor from it
