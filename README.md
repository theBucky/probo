# Probo

Probo is a tiny macOS menubar app that turns every mouse wheel notch into a fixed number of lines. One notch, one deterministic tick, every app, every time. Trackpads, momentum scrolling, and gesture phases pass through untouched.

If you've ever fought a mouse that scrolls inconsistently across apps, or jumps half a page in one app and a single line in another, Probo evens it out.

## Features

- Pick a line step per notch that's identical across every app, like 2 for slow or 3 for medium
- Rewrites discrete wheel events only, and passes continuous, phased, diagonal, and zero-delta events straight through
- Optional Option-key precision outside terminals, where holding Option drops to 1 line per notch
- Terminal-aware default that uses 1 line per notch in terminal apps and switches to your wheel step when you hold Option
- Natural (trackpad-style) scroll direction toggle
- Mouse button 4 mapped to macOS Look Up, on by default
- Launches at login through `SMAppService`
- No smoothing, momentum, acceleration, gesture-phase output, or user-configurable app lists

Every toggle lives in the Settings window. Open it from the menubar icon.

## Requirements

- macOS 26 or newer
- Apple silicon (arm64)
- Accessibility permission

## Install

Grab the latest signed build from [Releases](https://github.com/theBucky/probo/releases/latest), unzip it, drag `Probo.app` into `/Applications`, and launch.

On first launch, open the menubar icon or Settings to check Accessibility status. When you enable Probo or request access, macOS opens `System Settings > Privacy & Security > Accessibility`. Grant access there, and Probo turns on the event tap as soon as macOS reports the grant.

### Build from source

You'll need Xcode command line tools. Local builds codesign with a self-minted identity that's created automatically on first run.

```sh
scripts/dev/run.sh
```

The script writes the bundle to `build/Probo.app` and relaunches it. To skip codesigning, set `PROBO_CODESIGN_IDENTITY=-` for an ad-hoc signature.

## Architecture

Probo is a SwiftUI shell wrapped around a native Swift scroll-rewrite core. The tap callback reads raw `CGEvent` fields, applies a built-in terminal heuristic, asks the core for a rewrite decision, and synthesizes a replacement scroll event when the core says so. The hot path stays allocation-free, and policy logic stays out of the SwiftUI layer.

The source tree splits cleanly by concern:

| Layer | Path | Role |
| --- | --- | --- |
| App | `probo/Sources/App` | Lifecycle and controller wiring |
| Core | `probo/Sources/Core` | Pure scroll-rewrite hot path |
| Events | `probo/Sources/Events` | Event tap and scroll-event synthesis |
| Configuration | `probo/Sources/Configuration` | Settings model and persistence |
| System | `probo/Sources/System` | Accessibility, frontmost-app, and launch-at-login glue |
| UI | `probo/Sources/UI` | Menubar and settings views |
| Tools | `probo/Tools` | Developer-only Swift probes and diagnostics |

## Develop

There's no SwiftPM manifest and no Xcode project. Shell scripts drive everything.

| Script | Purpose |
| --- | --- |
| `swift-format format -i -r probo/Sources probo/Tests` | Format Swift sources and tests |
| `scripts/test.sh` | Build and run the BDD-style Swift tests |
| `scripts/build.sh` | Build the app and codesign the bundle (shared with CI) |
| `scripts/dev/lsp.sh` | Generate `compile_commands.json` for SourceKit-LSP |
| `scripts/dev/run.sh` | Build, then relaunch `Probo.app` |
| `scripts/dev/setup-codesign.sh` | Mint the local signing identity |
| `scripts/profiling/hot-path.sh` | Build and run hot-path micro profiles or xctrace recordings |
| `scripts/ci/mint-identity.sh` | Emit p12 and passphrase for CI release-signing secrets |

Re-run `scripts/dev/lsp.sh` whenever the source layout or compiler flags change so IDE diagnostics use the same SDK, target, frameworks, and source sets as the shell build.

## Release

CI runs on every push and PR. After CI passes on `main`, CD publishes a rolling `latest` GitHub release with a signed arm64 zip.

Release signing reads the `PROBO_RELEASE_P12_BASE64` and `PROBO_RELEASE_P12_PASSWORD` secrets. If either is missing, the build falls back to ad-hoc signing and emits a warning.

## License

[MIT](https://opensource.org/license/mit)
