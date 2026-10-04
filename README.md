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
- Pass-through for continuous and phased events; diagonal and zero-delta wheel events are dropped

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

SwiftPM owns the build graph for the app, core library, tests, profiling executable, and SourceKit-LSP. Read the core top-down: the SwiftUI surface binds to `Runtime`; `Runtime` persists `AppConfiguration` and applies it to `InputPipeline` and the idle-sleep assertion whenever configuration or Accessibility trust changes; `InputPipeline` owns the event tap and publishes configuration and terminal focus to its callback thread through atomics; each scroll callback hands the `CGEvent` to `ScrollRewriter`, which classifies a wheel notch, asks `ScrollPolicy` for the line step, then mutates the event in place or posts an Option-stripped replacement. Hot path is allocation-free.

| Module | Path | Role |
| --- | --- | --- |
| Package | `Package.swift` | SwiftPM products, targets, platforms |
| App | `Sources/Probo` | Entry point, menu bar, settings window, resources |
| Runtime | `Sources/ProboCore/Runtime.swift`, `Configuration.swift` | Orchestration, configuration model, persistence |
| Input | `Sources/ProboCore/Input` | Event tap lifecycle, scroll rewriting, pure scroll policy |
| System | `Sources/ProboCore/System` | Accessibility, sleep, and login adapters |
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
