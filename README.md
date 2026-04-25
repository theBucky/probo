# Probo

Menubar macOS app that remaps mouse wheel notches to fixed line steps. Each notch becomes one discrete line `CGEvent`, so apps see a deterministic tick. Trackpads, momentum, and gesture phases stay untouched.

## Features

- Fixed `N`-line step per notch, identical across apps
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

Requires Xcode command line tools. Local builds codesign with a self-minted identity (auto-created on first run).

```sh
bash scripts/local/run.sh
```

The bundle lands in `build/Probo.app` and relaunches. Override the signing identity with `PROBO_CODESIGN_IDENTITY=-` for ad-hoc signing.

## Architecture

Swift/AppKit app with a native Swift scroll rewrite core.

| Layer | Path | Role |
| --- | --- | --- |
| App | `macos/Sources/App` | App lifecycle and controller wiring |
| Core | `macos/Sources/Core` | Pure scroll rewrite hot path |
| Events | `macos/Sources/Events` | Event tap and scroll event synthesis |
| Configuration | `macos/Sources/Configuration` | App settings model and persistence |
| System | `macos/Sources/System` | Accessibility and launch-at-login glue |
| UI | `macos/Sources/UI` | Menubar UI |

The tap callback reads raw `CGEvent` fields, asks the Swift core for a rewrite decision, and synthesizes a replacement scroll event when asked.

The hot path stays allocation-free and keeps policy logic out of AppKit glue.

## Develop

No SwiftPM, no Xcode project. Shell scripts drive everything.

| Script | Purpose |
| --- | --- |
| `scripts/build.sh` | Build Swift app and codesign bundle (shared with CI) |
| `scripts/local/run.sh` | Build then relaunch `Probo.app` |
| `scripts/local/setup-codesign.sh` | Mint local signing identity |
| `scripts/ci/mint-identity.sh` | Emit p12 + passphrase for CI release-signing secrets |

## Release

CI runs on every push and PR. CD publishes a rolling `latest` GitHub release with a signed arm64 zip after CI passes on `main`.

Release signing uses the `PROBO_RELEASE_P12_BASE64` and `PROBO_RELEASE_P12_PASSWORD` secrets; missing secrets fall back to ad-hoc signing with a warning.

## License

[MIT](https://opensource.org/license/mit)
