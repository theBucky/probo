# Probo

Menubar macOS app remapping mouse-wheel ticks to fixed line steps. AppKit status-item shell hosting a SwiftUI settings form, with a native Swift rewrite core.

## Stack

- Latest Swift; no legacy API or syntax
- AppKit `NSStatusItem` + `NSMenu` for the status surface; `NSWindow` hosts the SwiftUI settings `Form` via `NSHostingController`
- `swiftc` flags in [build.sh](scripts/build.sh) are the only Swift gate; target `macos15.0`, `-swift-version 6 -O`

## Layout

- [App](probo/Sources/App): app lifecycle and controller wiring
- [Core](probo/Sources/Core): pure scroll rewrite hot path
- [Events](probo/Sources/Events): event tap and synth
- [Configuration](probo/Sources/Configuration): config model and persistence
- [System](probo/Sources/System): permission and launch-at-login glue
- [UI](probo/Sources/UI): status menu (AppKit) and settings form (SwiftUI)

## Validation

- format: `swift-format format -i -r probo/Sources probo/Tests`
- test: `scripts/test.sh`
- build: `scripts/build.sh`

## Invariants

- Tap callback is hot; keep Swift core allocation-free
- Rewrite core drops continuous, phased, diagonal, zero-delta events; extend, never loosen
- No smoothing, momentum, acceleration, or gesture-phase output
- Per-app behavior is limited to built-in ecosystem heuristics (e.g. terminal-aware precision); no user-configurable app lists

## Local

- [refs/](refs) is read-only inspiration; never edit or vendor from it
