# Probo

Menubar macOS app that remaps mouse wheel ticks to fixed line steps. Rewrites each discrete wheel event into a clean multi-line scroll, leaves trackpads and momentum alone.

## Why

macOS treats a single mouse notch as a tiny, variable-sized nudge. Probo replaces that with a fixed `N`-line step so every notch feels the same across apps.

- rewrites discrete wheel events only
- passes through continuous, phased, diagonal, and zero-delta events (trackpads untouched)
- no smoothing, momentum, acceleration, gesture phase, or per-app rules

## Install

Requires macOS 26 and a Rust toolchain. Local builds codesign with a self-minted identity.

```sh
# build, sign, relaunch Probo.app
bash scripts/local/run.sh
```

The app lives in `build/Probo.app`. Grant Accessibility permission on first launch (System Settings, Privacy and Security, Accessibility).

## Use

Click the menubar icon.

```
Probo
┌──────────────────────┐
│ ✓ Enable             │
├──────────────────────┤
│   Intensity        ▸ │
│   Misc             ▸ │
├──────────────────────┤
│   Start at Login     │
├──────────────────────┤
│   Quit            ⌘Q │
└──────────────────────┘

Intensity ▸
┌────────────┐
│ ✓ Slow     │
│   Medium   │
└────────────┘

Misc ▸
┌────────────────────────────────┐
│ ✓ Look Up on Button 4          │
│   Precision Scroll on Option   │
└────────────────────────────────┘
```

- **Enable**: toggles the event tap
- **Intensity**: `Slow` (2 lines per notch) or `Medium` (4 lines per notch)
- **Misc > Look Up on Button 4**: forwards the forward side button to the system Look Up shortcut
- **Misc > Precision Scroll on Option**: holding Option halves the step while scrolling
- **Launch at Login**: registers via `SMAppService`

Settings persist in `UserDefaults`.

## Architecture

Swift/AppKit shell over a Rust `staticlib` core, bridged via a C FFI header.

| layer | path | role |
| --- | --- | --- |
| shell | `macos/Sources` | menubar UI, event tap, scroll synth, config store |
| core | `runtime/src/lib.rs` | `probo_process_wheel` hot path |
| bridge | `runtime/include/probo_runtime.h` | shared C FFI contract |

The tap callback forwards the raw `CGEvent` fields to Rust, receives a rewrite decision, and synthesizes a replacement scroll event when asked. Swift stays allocation-free on the hot path.

## Build

No SwiftPM, no Xcode project. Shell scripts drive everything.

| script | purpose |
| --- | --- |
| `scripts/build.sh` | rebuild Rust lib, link Swift, codesign bundle (shared with CI) |
| `scripts/local/run.sh` | build then relaunch `Probo.app` |
| `scripts/local/bench.sh` | hot-path cost, optional iteration count |
| `scripts/local/compare.sh` | immediate vs frame-aligned output |
| `scripts/local/setup-codesign.sh` | mint local signing identity |
| `scripts/ci/mint-identity.sh` | emit p12 + passphrase for CI release-signing secrets |

Override the signing identity with `PROBO_CODESIGN_IDENTITY`.

## License

MIT.
