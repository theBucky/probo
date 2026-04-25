# Probo

menubar macOS app remapping mouse-wheel ticks to fixed line steps. swift/appkit shell with a native swift rewrite core.

## Layout

- [macos/Sources/App/](macos/Sources/App): app lifecycle and controller wiring
- [macos/Sources/Core/](macos/Sources/Core): pure scroll rewrite hot path
- [macos/Sources/Events/](macos/Sources/Events): event tap and synth
- [macos/Sources/Configuration/](macos/Sources/Configuration): app config model and persistence
- [macos/Sources/System/](macos/Sources/System): permission and launch-at-login glue
- [macos/Sources/UI/](macos/Sources/UI): status menu
- [macos/Resources/Info.plist](macos/Resources/Info.plist): bundle plist
- [scripts/build.sh](scripts/build.sh): single source of truth for swift build and codesign; CI calls the same script
- [scripts/local/](scripts/local) and [scripts/ci/](scripts/ci): `run.sh` and codesign mint helpers

## Validate

- swift: `scripts/build.sh`

## Invariants

- `swiftc` flags in [build.sh](scripts/build.sh) are the only swift gate; target `macos26.0`, `-swift-version 6 -O`
- tap callback is hot; keep swift core allocation-free
- rewrite core drops continuous, phased, diagonal, zero-delta events; extend, never loosen
- no rejects smoothing, momentum, acceleration, gesture-phase output, per-app rules

## Local

- [refs/](refs) is read-only inspiration; never edit or vendor from it
