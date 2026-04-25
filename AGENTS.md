# Probo

menubar macOS app remapping mouse-wheel ticks to fixed line steps. swift/appkit shell with a native swift rewrite core.

## Layout

- [probo/Sources/App/](probo/Sources/App): app lifecycle and controller wiring
- [probo/Sources/Core/](probo/Sources/Core): pure scroll rewrite hot path
- [probo/Sources/Events/](probo/Sources/Events): event tap and synth
- [probo/Sources/Configuration/](probo/Sources/Configuration): app config model and persistence
- [probo/Sources/System/](probo/Sources/System): permission and launch-at-login glue
- [probo/Sources/UI/](probo/Sources/UI): status menu
- [probo/Resources/Info.plist](probo/Resources/Info.plist): bundle plist
- [scripts/build.sh](scripts/build.sh): single source of truth for swift build and codesign; CI calls the same script
- [scripts/lsp.sh](scripts/lsp.sh): emits `compile_commands.json` for SourceKit-LSP
- [scripts/local/](scripts/local) and [scripts/ci/](scripts/ci): `run.sh` and codesign mint helpers

## Validate

- format: `swift-format format -i -r probo/Sources probo/Tests`
- lsp: `scripts/lsp.sh`
- test: `scripts/test.sh`
- build: `scripts/build.sh`

## Invariants

- `swiftc` flags in [build.sh](scripts/build.sh) are the only swift gate; target `macos26.0`, `-swift-version 6 -O`
- tap callback is hot; keep swift core allocation-free
- rewrite core drops continuous, phased, diagonal, zero-delta events; extend, never loosen
- no rejects smoothing, momentum, acceleration, gesture-phase output, per-app rules

## Local

- [refs/](refs) is read-only inspiration; never edit or vendor from it
