# Probo

[![CI](https://github.com/theBucky/probo/actions/workflows/ci.yml/badge.svg)](https://github.com/theBucky/probo/actions/workflows/ci.yml)
[![Platform](https://img.shields.io/badge/platform-macOS%2015%2B-blue)](https://www.apple.com/macos)
[![Swift](https://img.shields.io/badge/swift-6-orange)](https://swift.org)
[![License](https://img.shields.io/badge/license-MIT-green)](https://opensource.org/license/mit)

macOS menu bar utility that rewrites each mouse-wheel notch to a fixed line step. Trackpad input, momentum, and gesture phases pass through untouched.

## Features

- Fixed step per notch: Slow (2 lines) or Medium (3 lines)
- Option-key precision drops to 1 line per notch
- Terminal heuristic emits 1 line per notch in supported terminal apps, configured step when Option is held
- Natural scroll-direction toggle
- Mouse button 4 maps to the macOS Look Up gesture
- Optional sleep-prevention assertion while enabled; display sleep, lid close, and manual sleep still fire
- Launch at login via `SMAppService`
- Pass-through for continuous, phased, diagonal, and zero-delta events

Settings live in a single window opened from the menu bar icon.

## Requirements

- macOS 15+
- Apple silicon (arm64)
- Accessibility permission

## Install

Download the signed arm64 archive from [Releases](https://github.com/theBucky/probo/releases/latest) and drop `Probo.app` into `/Applications`.

First launch routes through the menu bar icon. Enabling Probo or selecting Request Access opens `System Settings > Privacy & Security > Accessibility`; the event tap installs as soon as macOS reports the grant.

## Build

Requires Xcode command-line tools. Local builds codesign with a self-minted identity created on first run.

```sh
scripts/dev/run.sh
```

Writes `build/Probo.app` and relaunches it. Set `PROBO_CODESIGN_IDENTITY=-` for ad-hoc signing.

## Architecture

SwiftPM owns the build graph for the app, tests, profiling executable, and SourceKit-LSP. AppKit owns the menu bar item, status menu, settings window, and settings controls over a native Swift rewrite core. The event-tap callback reads raw `CGEvent` fields, applies the terminal heuristic, asks the core for a rewrite decision, and synthesizes a replacement scroll event when needed. Hot path is allocation-free.

| Layer | Path | Role |
| --- | --- | --- |
| Package | `Package.swift` | SwiftPM products, targets, platforms, resources |
| App | `Sources/Probo`, `Sources/ProboCore/App` | Entry point, resources, runtime wiring |
| Core | `Sources/ProboCore/Core` | Pure rewrite hot path |
| Events | `Sources/ProboCore/Events` | Event tap, scroll synthesis |
| Configuration | `Sources/ProboCore/Configuration` | Settings model, persistence |
| System | `Sources/ProboCore/System` | Accessibility, frontmost app, sleep, login |
| UI | `Sources/ProboCore/UI` | Status menu and settings controls |
| Tools | `Sources/HotPathProfile` | Profiling executable and entitlements |
| Tests | `Tests/ProboTests` | Swift Testing suites |

## Development

SwiftPM is canonical. Shell scripts wrap SwiftPM where app bundling, signing, launch, or profiling need extra macOS steps.

| Command | Purpose |
| --- | --- |
| `swift-format format -i -r Sources Tests` | Format sources and tests |
| `swift test` | Run Swift Testing suites and CI test gate |
| `scripts/build.sh` | Build and codesign `build/Probo.app` |
| `scripts/dev/run.sh` | Build and relaunch `Probo.app` |
| `scripts/dev/setup-codesign.sh` | Create local signing identity |
| `scripts/profiling/hot-path.sh` | Hot-path micro profiles or xctrace recordings |
| `scripts/ci/mint-identity.sh` | Emit p12 and passphrase for CI signing secrets |

## Release

CI runs on every push and pull request. CD publishes a rolling `latest` GitHub release with a signed arm64 archive after CI passes on `main`.

Release signing reads `PROBO_RELEASE_P12_BASE64` and `PROBO_RELEASE_P12_PASSWORD`. Missing either falls back to an ad-hoc signature with a warning.

## License

[MIT](https://opensource.org/license/mit)
