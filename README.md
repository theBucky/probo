# Probo

Probo is a macOS menu bar utility that converts each mouse-wheel notch into a fixed number of scroll lines. It addresses mice that produce inconsistent scroll distances across applications. Trackpad input, momentum, and gesture phases are not modified.

## Features

- Fixed line step per notch, selectable as Slow (2 lines) or Medium (3 lines)
- Pass-through for continuous, phased, diagonal, and zero-delta scroll events
- Optional Option-key precision that drops to one line per notch
- Terminal-aware default that emits one line per notch in terminal apps and applies the configured step when Option is held
- Natural scroll-direction toggle
- Mouse button 4 mapped to the macOS Look Up gesture
- Optional automatic-sleep prevention while Probo is enabled, with display sleep, lid close, and manual sleep still permitted
- Launch at login through `SMAppService`

All options are exposed in the Settings window, which opens from the menu bar icon.

## Requirements

- macOS 26 or later
- Apple silicon (arm64)
- Accessibility permission

## Installation

Download the latest signed build from [Releases](https://github.com/theBucky/probo/releases/latest), expand the archive, and move `Probo.app` into `/Applications`.

On first launch, open the menu bar icon to review Accessibility status. Enabling Probo or selecting Request Access opens `System Settings > Privacy & Security > Accessibility`. Probo installs the event tap as soon as macOS reports the grant.

### Build from source

The build requires Xcode command-line tools. Local builds codesign with a self-minted identity that is created on first run.

```sh
scripts/dev/run.sh
```

The script writes the bundle to `build/Probo.app` and relaunches it. Set `PROBO_CODESIGN_IDENTITY=-` to apply an ad-hoc signature instead.

## Architecture

Probo is an AppKit `NSStatusItem` shell that hosts a SwiftUI settings form and wraps a native Swift rewrite core. The event-tap callback reads raw `CGEvent` fields, applies the built-in terminal heuristic, asks the core for a rewrite decision, and synthesizes a replacement scroll event when one is required. The hot path remains allocation-free.

The source tree is partitioned by concern.

| Layer | Path | Role |
| --- | --- | --- |
| App | `probo/Sources/App` | Lifecycle and controller wiring |
| Core | `probo/Sources/Core` | Pure scroll-rewrite hot path |
| Events | `probo/Sources/Events` | Event tap and scroll synthesis |
| Configuration | `probo/Sources/Configuration` | Settings model and persistence |
| System | `probo/Sources/System` | Accessibility, frontmost-app, sleep, and login glue |
| UI | `probo/Sources/UI` | Menu bar (AppKit) and Settings (SwiftUI) |
| Tools | `probo/Tools` | Developer probes and diagnostics |

## Development

The project ships without a SwiftPM manifest or Xcode project. Shell scripts drive every workflow.

| Script | Purpose |
| --- | --- |
| `swift-format format -i -r probo/Sources probo/Tests` | Format Swift sources and tests |
| `scripts/test.sh` | Build and run the BDD-style Swift tests |
| `scripts/build.sh` | Build and codesign the app bundle (shared with CI) |
| `scripts/dev/lsp.sh` | Generate `compile_commands.json` for SourceKit-LSP |
| `scripts/dev/run.sh` | Build and relaunch `Probo.app` |
| `scripts/dev/setup-codesign.sh` | Create the local signing identity |
| `scripts/profiling/hot-path.sh` | Run hot-path micro profiles or xctrace recordings |
| `scripts/ci/mint-identity.sh` | Emit a p12 and passphrase for CI signing secrets |

Re-run `scripts/dev/lsp.sh` whenever the source layout or compiler flags change so the IDE uses the same SDK, target, frameworks, and source set as the shell build.

## Release

CI runs on every push and pull request. After CI passes on `main`, CD publishes a rolling `latest` GitHub release with a signed arm64 archive.

Release signing reads the `PROBO_RELEASE_P12_BASE64` and `PROBO_RELEASE_P12_PASSWORD` secrets. If either is missing, the build falls back to an ad-hoc signature and emits a warning.

## License

[MIT](https://opensource.org/license/mit)
