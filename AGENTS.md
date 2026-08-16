# Probo

Menubar macOS app remapping mouse-wheel ticks to fixed line steps.

## Repo Structure

```text
Package.swift                 SwiftPM graph for app, tests, and profiling tool
Sources/
├── Probo                     app entry point, menu bar, settings scene, resources
├── ProboCore/
│   ├── App                   observable runtime, persisted settings, settings UI
│   ├── Input                 mouse pipeline: configuration, tap, scroll policy, output
│   └── System                Accessibility, launch-at-login, power adapters
└── HotPathProfile            scroll hot-path benchmarks and entitlements
Tests/ProboTests              Swift Testing behavior coverage
scripts                       build, signing, development, CI, profiling workflows
refs                          read-only inspiration; never edit or vendor
```

## Environment Requirements

- Latest Swift syntax and idioms.
- macOS 15.0 minimum deployment target.
- Apple silicon target.
- SwiftPM is the source of truth for build graph and SourceKit-LSP.
- `scripts/build.sh` is the app-bundle signing gate.

## Commands

- Format: `swift-format format -i -r Sources Tests`
- Test: `swift test`
- Build: `scripts/build.sh`
- Run locally: `scripts/dev/run.sh`
- Hot-path profile: `scripts/profiling/hot-path.sh`

## General Coding Rules

- Keep the tap callback allocation-free. No locks, lookups, persistence, logging, async work, or heap allocations in the scroll hot path.
- Pass continuous and phased events through untouched; they are trackpad and Magic Mouse gestures, never wheel notches. Drop diagonal and zero-delta wheel events; only make that drop policy stricter.
- Do not add smoothing, momentum, acceleration, or gesture-phase output.
- Keep per-app behavior to built-in ecosystem heuristics. No user-configurable app lists.
