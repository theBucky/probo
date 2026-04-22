# mouse scrolling utility high-level plan

## goal

build a small macos background app with a menubar icon that improves mouse wheel scrolling feel.

target feel:
- default mode feels closer to windows wheel scrolling
- no fake smooth scrolling by default
- low latency
- predictable stop behavior
- minimal cpu and event-pipeline complexity
- crisp for 120hz displays in v1

non-goals for v1:
- full trackpad emulation
- inertia-heavy animation
- giant settings surface
- broad per-app compatibility hacks
- shortcuts or unrelated input features
- smooth animated scrolling
- scroll direction inversion

## product shape

two-process mental model is unnecessary for v1.

preferred shape:
- one macos app
- launches as agent app with menubar item
- asks for accessibility permission
- installs global scroll event tap
- rewrites wheel input into fixed-line scroll output

chosen tech split:
- swift/appkit shell for app lifecycle, menubar, permissions, launch at login
- rust core for event processing, fixed-step mapping, and output decisions

fallback:
- keep ffi boundary thin if integration cost grows
- reconsider pure swift only for temporary bring-up, not as target architecture

## refs takeaways

refs project proves these pieces are enough:
- `accessibility + event tap + menubar`
- `delta remap`
- `re-emitted scroll events`

refs also shows what to avoid in v1:
- coupling low-latency path with smoothness and momentum features
- large state machine for many scroll modes
- switching between multiple output styles too early
- deep compatibility behavior before baseline feel is good
- mixing scrolling core with unrelated feature work

## v1 architecture

### app shell
- [x] agent app with status item
- [x] menu entries: enabled, start at login, quit
- [x] tiny persisted config
- [x] no settings window required for v1

### input pipeline
- [x] capture `kCGEventScrollWheel`
- [x] ignore trackpad-like continuous events
- [x] focus on detented mouse wheel input first
- [x] keep tap callback minimal and non-blocking

### processing core
- [x] map each detent to a fixed line step
- [x] keep behavior uniform across isolated ticks and bursts
- [x] avoid long-lived swipe counters and momentum state in baseline mode
- [x] keep hot path inside rust
- [ ] tune for 120hz perception in v1
- [ ] validate final values across core app surfaces

### output pipeline
- [x] emit line-based scroll events
- [x] no gesture-phase output in baseline mode
- [x] keep immediate direct repost as the only v1 output path
- [x] never add smoothing layers that cost crispness

## algorithm direction

baseline mode should treat wheel input as discrete impulses, not pseudo-touch.

first algorithm sketch:
- single tick gets fixed base line distance
- consecutive ticks keep the same per-tick distance
- direction flip takes effect immediately
- no tail animation after user stops

algorithm priorities:
- latency first, then consistency, then tunability
- optimize for crisp 120fps rendering, not buttery interpolation
- every tick should feel immediate and legible
- reject any mechanism that hides wheel detents behind smoothing
- reject any form of scroll acceleration
- avoid extra feature branches in hot path

performance targets:
- no dropped-feel bursts on 120hz displays under rapid wheel input
- tap callback stays tiny and deterministic
- processing and scheduling budget fits comfortably inside one frame at 120hz
- future refresh-rate matching stays possible without rewriting core

design constraints:
- `o(1)` work per event
- no heap churn on hot path if avoidable
- no dependency on app-under-cursor lookup
- no smoothing that adds visible lag
- no unrelated features in core event pipeline
- no shortcut handling in this app
- no animation engine in baseline mode

## implementation phases

### phase 0 - scaffold
- [x] create app shell
- [x] add menubar item
- [x] add accessibility permission flow
- [x] add event tap install and teardown

### phase 1 - passthrough re-emitter
- [x] capture detented wheel events
- [x] suppress original event
- [x] re-emit equivalent pixel-based event
- [ ] verify stability across finder, browser, editor

### phase 2 - baseline remap
- [x] add fixed-step remap
- [x] expose the default `slow` preset
- [x] expose `medium`
- [ ] tune for low latency and natural stop behavior
- [ ] tune explicitly on 120hz hardware behavior
- [x] benchmark immediate direct repost against frame-aligned coalescing
- [x] keep immediate direct repost for v1
- [x] keep runtime-only comparison tooling for local verification

### phase 3 - polish
- [x] persist settings
- [x] launch at login
- [ ] import/export preset json or plist if useful

## early preset plan

ship very few knobs first:
- [x] mode: `constant-step`
- [x] intensity: `slow`, `medium`
- [x] enabled

## evaluation criteria

we should judge each iteration on:
- [x] latency under single tick
- [x] consistency under 2 to 5 quick ticks
- [x] stop behavior after burst
- [x] direction-change control
- [x] cpu cost while rapidly scrolling
- [ ] subjective feel in browser, code editor, long text view
- [ ] crispness at 120hz
- [ ] absence of detent-smearing

## resolved decisions

- v1 uses `rust core + swift shell`
- v1 targets `120hz` behavior only
- future refresh-rate matching is an extension point, not a v1 goal
- v1 keeps immediate direct repost as the only output path
- ffi boundary stays thin, but rust owns scrolling core and tuning logic
- v1 optimizes for detented wheel input first
- non-detented or unusual devices may passthrough in v1
- v1 has no per-app exceptions unless a concrete blocker appears
- v1 does not depend on app-side diagnostics or tracing
- v1 chooses runtime-local benchmark scripts for implementation comparisons

## next document candidates

when ready, split this into:
- `docs/architecture.md`
- `docs/algorithm.md`
- `docs/ffi-boundary.md`
- `docs/tuning-notes.md`
- `docs/macos-permissions-and-distribution.md`
