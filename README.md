# Probo

Menubar macOS app that remaps mouse wheel notches to fixed line steps. Each discrete tick keeps a consistent total line count and can be split into unit line events for a higher-frequency, Windows-like feel. Trackpads, momentum, and gesture phases stay untouched.

## Features

- Fixed `N`-line step per notch, identical across apps
- `High Performance` mode splits each notch into unit line events without smoothing or acceleration
- `Native` mode emits one native line event per notch
- Rewrites discrete wheel events only; passes continuous, phased, diagonal, and zero-delta events through
- Option-hold precision scroll (1 line per notch)
- Forward side button (button 4) mapped to macOS Look Up
- Launch at login via `SMAppService`
- No smoothing, momentum, acceleration, gesture-phase output, or per-app rules

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

| Layer | Path | Role |
| --- | --- | --- |
| Shell | `macos/Sources` | Menubar UI, event tap, scroll synth, config store |
| Core | `runtime/src/lib.rs` | `probo_process_wheel` hot path |
| Bridge | `runtime/include/probo_runtime.h` | Shared C FFI contract |

The tap callback forwards raw `CGEvent` fields to Rust, receives a rewrite decision, and synthesizes a replacement scroll event when asked.

Swift stays allocation-free on the hot path.

## Develop

No SwiftPM, no Xcode project. Shell scripts drive everything.

| Script | Purpose |
| --- | --- |
| `scripts/build.sh` | Rebuild Rust lib, link Swift, codesign bundle (shared with CI) |
| `scripts/local/run.sh` | Build then relaunch `Probo.app` |
| `scripts/local/bench.sh [iterations]` | Hot-path cost |
| `scripts/local/compare.sh` | Immediate vs frame-aligned output |
| `scripts/local/setup-codesign.sh` | Mint local signing identity |
| `scripts/ci/mint-identity.sh` | Emit p12 + passphrase for CI release-signing secrets |

## Release

CI runs on every push and PR. CD publishes a rolling `latest` GitHub release with a signed arm64 zip after CI passes on `main`.

Release signing uses the `PROBO_RELEASE_P12_BASE64` and `PROBO_RELEASE_P12_PASSWORD` secrets; missing secrets fall back to ad-hoc signing with a warning.

## License

[MIT](https://opensource.org/license/mit)
