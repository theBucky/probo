# v1 scrolling algorithm draft

## scope

this document defines the `v1` behavior for the scrolling core.

hard constraints:
- `rust` owns hot path logic
- optimize for `120hz` displays only in v1
- no smooth animation
- no momentum
- no direction inversion
- no shortcuts or unrelated features
- no per-app behavior branches in v1
- no scroll acceleration

## terminology

- `detented wheel`: wheel input that arrives as discrete ticks
- `notched wheel`: hardware with physical ratchet steps
- in practice, v1 treats these as the same target class
- `continuous wheel`: devices that already emit continuous or gesture-like scroll

practical rule:
- v1 optimizes discrete wheel ticks
- continuous-like input passes through untouched unless proven safe later

## behavior goal

make wheel scrolling feel immediate, crisp, uniform, and controllable.

desired user perception:
- single tick responds instantly
- each tick has the same travel distance
- rapid bursts remain crisp instead of smeared
- stopping input stops motion immediately
- direction reversal feels sharp and authoritative

## non-goals

- hiding wheel detents
- simulating trackpad phases
- easing or trailing motion after input stops
- generating synthetic momentum
- adapting to every display refresh rate in v1
- changing travel distance based on wheel speed

## pipeline

### 1. capture
- intercept `kCGEventScrollWheel`
- read essential fields only
- classify event as `candidate_for_rewrite` or `passthrough`

candidate rules for v1:
- non-continuous event
- axis-aligned event
- not obviously trackpad or gesture-originated

passthrough rules for v1:
- `isContinuous != 0`
- gesture or phase-like event fields already populated
- diagonal or unusual wheel data
- unsupported source classification

### 2. state update
- keep minimal state only
- no burst-speed model
- no cadence-derived gain

state sketch:
- last direction

### 3. fixed-step mapping
- convert one wheel tick into one fixed pixel delta
- output depends only on direction, axis, and selected intensity
- input speed never changes per-tick travel

formula shape:
- `pixels = sign * step_px`

properties:
- deterministic
- constant
- easy to reason about
- closest to target windows-like wheel feel

## proposed v1 mapping

### parameters
- `step_px_slow = 24`
- `step_px_medium = 72`

these are starting points, not locked values.

### meaning
- every vertical tick emits exactly `step_px_*` vertical pixels
- every horizontal tick emits exactly `step_px_*` horizontal pixels
- rapid bursts produce repeated equal-size steps

## output strategy

### default v1 path
- suppress original event
- synthesize one pixel-based continuous scroll event immediately
- post on same logical handling path with minimal delay

why:
- lowest complexity
- lowest latency
- no interpolation layer
- easiest route to crisp 120hz feel
- retained after runtime benchmark comparison against frame-aligned coalescing

### emitted event shape
- use continuous pixel scroll event
- set only fields required for natural app behavior
- avoid gesture phase fields
- avoid momentum phase fields

### axis handling
- vertical and horizontal use same machinery
- diagonal unsupported in v1 rewrite path
- diagonal input passes through

## direction-change rules

direction reversal is immediate.

rules:
- no carry-over state affects travel distance
- first tick in reverse direction uses the same fixed step
- no cancellation animation because no animation exists

goal:
- reverse scroll should never feel sticky or delayed

## unusual input handling

v1 should fail simple.

passthrough on:
- continuous-source events
- diagonal wheel input
- malformed fields
- unsupported device class

drop only on:
- events we explicitly rewrite and replace successfully

## refresh-rate strategy

v1 is tuned for `120hz`.

important distinction:
- algorithm is not frame-driven
- tuning assumes `120hz` display perception

v1 decision:
- no refresh-specific branching
- no display-linked emitter
- no alternate output scheduler in v1

## performance budget

hot path goals:
- no allocations on normal event path
- no locks if single-threaded state is feasible
- no objc object graph churn inside rust path
- no app lookup
- no device-property fetches on each tick
- no timing-based gain logic

ffi goals:
- pass primitive event fields into rust
- get back primitive decision plus fixed delta
- keep boundary serialization-free

## rust ffi boundary sketch

swift side responsibilities:
- install event tap
- extract compact event fields
- call rust core
- synthesize/post replacement event

rust side responsibilities:
- classify supported input
- choose fixed output delta

ffi note:
- scrolling core implementation remains `rust`
- `swift` calls rust through a thin `c abi` layer
- the following sketch describes the abi boundary, not the implementation language

minimal c abi sketch exported by rust:

```c
typedef struct {
  uint64_t timestamp_ns;
  int32_t delta_axis1;
  int32_t delta_axis2;
  uint8_t is_continuous;
  uint8_t has_phase;
} wheel_input_t;

typedef struct {
  uint8_t rewrite;
  int32_t out_dx;
  int32_t out_dy;
} wheel_output_t;

wheel_output_t probo_process_wheel(wheel_input_t input);
void probo_reset_scroll_state(void);
```

## tuning plan

### first tuning loop
- verify direct single-tick latency
- tune `step_px_slow`
- tune `step_px_medium`
- verify equal travel across isolated and rapid wheel use
- verify no hidden acceleration appears

### test surfaces
- browser long page
- code editor
- finder list
- settings-like table views

### failure smells
- single tick moves too little or too much
- repeated ticks feel uneven
- rapid burst looks smeared despite fixed step
- reverse direction feels sticky
- different wheel speeds cause different per-tick travel

## verification

local verification uses runtime-only scripts:
- `./scr/compare.sh` for scenario comparison
- `./scr/bench.sh` for cpu and latency comparison
- app-side logging and tracing are intentionally excluded from v1

## v1 exclusions

explicitly excluded from this algorithm:
- smooth interpolated output
- synthetic momentum
- gesture scroll simulation
- per-app rules
- scroll inversion
- shortcut handling
- any cadence-based acceleration
- any burst-based travel gain

## likely next revision topics

- display-linked emitter if direct repost lacks crispness
- better device classification
- refresh-aware parameter families beyond `120hz`
- alternate constant-step presets after baseline is validated
