# Probo

Menubar macOS app remapping mouse-wheel ticks to fixed line steps.

## Project Map

- `Package.swift`: canonical SwiftPM package graph for app, tests, and profiling tool.
- `Sources/Probo`: executable entry point, app delegate, and app resources.
- `Sources/ProboCore/App`: runtime orchestration; AppKit app surface stays in the executable target.
- `Sources/ProboCore/UI`: status menu and settings content; AppKit owns all UI.
- `Sources/ProboCore/Core`: pure rewrite decisions; no AppKit, CoreGraphics, IOKit, persistence, or UI.
- `Sources/ProboCore/Events`: event tap, parsing, and synthesized output.
- `Sources/ProboCore/Configuration`: config model and `UserDefaults`.
- `Sources/ProboCore/System`: Accessibility, frontmost app, launch-at-login, power assertions.
- `Sources/HotPathProfile`: profiling executable and entitlements for the scroll hot path.
- `Tests/ProboTests`: Swift Testing coverage for app behavior.
- `refs/`: read-only inspiration. Do not edit or vendor from it.

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

- Use direct AppKit APIs when they express the behavior. No adapters, wrappers, delayed tasks, mirrors, forwarding enums, or glue around one-step framework calls.
- Keep framework bridges at system boundaries: event tap, menu bar, window, permission, launch-at-login, power assertion. Keep core framework-free.
- Add helpers only for real invariants or repeated behavior. Delete one-use constants files, shims, compatibility layers, and pass-through abstractions.
- Keep the tap callback allocation-free. No locks, lookups, persistence, logging, async work, or heap allocations in the scroll hot path.
- Pass continuous and phased events through untouched; they are trackpad and Magic Mouse gestures, never wheel notches. Drop diagonal and zero-delta wheel events; only make that drop policy stricter.
- Do not add smoothing, momentum, acceleration, or gesture-phase output.
- Keep per-app behavior to built-in ecosystem heuristics. No user-configurable app lists.
- Validate external inputs at the boundary. Keep private code free of impossible-state defense.
- Prefer fewer files with clear ownership over tiny forwarding files. Split only for a real boundary or independently testable behavior.
