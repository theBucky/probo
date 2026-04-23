# Probo

Menubar macOS app that remaps mouse wheel notches to fixed line steps. Each discrete tick becomes a clean, consistent multi-line scroll. Trackpads, momentum, and gesture phases stay untouched.

## Features

- fixed `N`-line step per notch, identical across apps
- rewrites discrete wheel events only; passes continuous, phased, diagonal, and zero-delta events through
- Option-hold precision scroll (1 line per notch)
- forward side button (button 4) mapped to macOS Look Up
- launch at login via `SMAppService`
- no smoothing, momentum, acceleration, gesture-phase output, or per-app rules

## Requirements

- macOS 26 or newer
- Apple silicon (arm64)
- Accessibility permission (prompted on first launch)

## Install

Download the latest signed build from [Releases](https://github.com/theBucky/probo/releases/latest), unzip, drag `Probo.app` into `/Applications`, and launch.

First launch prompts for Accessibility (`System Settings > Privacy & Security > Accessibility`). Grant access, then click the menubar icon to toggle `Enable`.

### Build from source

Requires the Rust toolchain and Xcode command line tools. Local builds codesign with a self-minted identity (auto-created on first run).

```sh
bash scripts/local/run.sh
```

The bundle lands in `build/Probo.app` and relaunches. Override the signing identity with `PROBO_CODESIGN_IDENTITY=-` for ad-hoc signing.

## Architecture

Swift/AppKit shell over a Rust `staticlib` core, bridged via a C FFI header.

| layer | path | role |
| --- | --- | --- |
| shell | `macos/Sources` | menubar UI, event tap, scroll synth, config store |
| core | `runtime/src/lib.rs` | `probo_process_wheel` hot path |
| bridge | `runtime/include/probo_runtime.h` | shared C FFI contract |

The tap callback forwards raw `CGEvent` fields to Rust, receives a rewrite decision, and synthesizes a replacement scroll event when asked. Swift stays allocation-free on the hot path.

## Develop

No SwiftPM, no Xcode project. Shell scripts drive everything.

| script | purpose |
| --- | --- |
| `scripts/build.sh` | rebuild Rust lib, link Swift, codesign bundle (shared with CI) |
| `scripts/local/run.sh` | build then relaunch `Probo.app` |
| `scripts/local/bench.sh [iterations]` | hot-path cost |
| `scripts/local/compare.sh` | immediate vs frame-aligned output |
| `scripts/local/setup-codesign.sh` | mint local signing identity |
| `scripts/ci/mint-identity.sh` | emit p12 + passphrase for CI release-signing secrets |

Validate Rust with `cargo fmt`, `cargo clippy --all-targets -- -D warnings`, and `cargo test --release --manifest-path runtime/Cargo.toml`. Validate Swift and FFI with `scripts/build.sh`.

## Release

CI runs on every push and PR. CD publishes a rolling `latest` GitHub release with a signed arm64 zip after CI passes on `main`.

Release signing uses the `PROBO_RELEASE_P12_BASE64` and `PROBO_RELEASE_P12_PASSWORD` secrets; missing secrets fall back to ad-hoc signing with a warning.

## License

[MIT](https://opensource.org/license/mit)
