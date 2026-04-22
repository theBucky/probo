# Probo

Menubar macOS app that remaps mouse wheel ticks to fixed line steps. Swift/AppKit shell over a Rust `staticlib` core via C FFI.

## Map

- Swift shell: [macos/Sources](macos/Sources), bundle plist at [Info.plist](macos/Resources/Info.plist)
- Rust core: [runtime/src/lib.rs](runtime/src/lib.rs), simulator at [sim.rs](runtime/src/sim.rs), local bins in [src/bin](runtime/src/bin)
- FFI header: [probo_runtime.h](runtime/include/probo_runtime.h)
- Swift bridge: [RuntimeBridge.swift](macos/Sources/RuntimeBridge.swift)
- Build/run/bench scripts: [scripts/build.sh](scripts/build.sh), [scripts/run.sh](scripts/run.sh), [scripts/bench.sh](scripts/bench.sh), [scripts/compare.sh](scripts/compare.sh)

## Validate

After Rust changes: `cargo fmt`, `cargo clippy --all-targets -- -D warnings`, `cargo test --release` (all with `--manifest-path runtime/Cargo.toml`).

After Swift or FFI changes: `scripts/build.sh` (rebuilds Rust lib then links Swift). Use `scripts/run.sh` to relaunch the app.

Tuning: `scripts/bench.sh [iters]` for hot-path cost, `scripts/compare.sh` for immediate vs frame-aligned output.

## Caveats

- FFI structs in `lib.rs`, `probo_runtime.h`, and `RuntimeBridge.swift` must move together.
- No SwiftPM; `swiftc` flags in `scripts/build.sh` are the only Swift gate. Target is `macos26.0`, `-swift-version 6 -O`.
- Tap callback runs hot; keep Swift side allocation-free, push logic into Rust.
- `should_passthrough` intentionally drops continuous, phased, diagonal, zero-delta events. Extend, do not loosen.
- v1 rejects smoothing, momentum, acceleration, gesture-phase output, per-app rules.
- Local codesign identity is minted by [setup-local-codesign.sh](scripts/setup-local-codesign.sh); override with `PROBO_CODESIGN_IDENTITY`.
- [refs/](refs) is read-only inspiration; never edit or vendor from it.
