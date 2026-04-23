use std::hint::black_box;
use std::ops::AddAssign;
use std::time::Instant;

use crate::{
    PROBO_INTENSITY_MEDIUM, PROBO_INTENSITY_SLOW, probo_process_wheel, probo_wheel_input_t,
    process_core,
};

const HOT_TRIALS: usize = 5;

#[derive(Clone, Copy)]
struct SimInput {
    timestamp_ns: u64,
    delta_axis1: i32,
    delta_axis2: i32,
    is_continuous: bool,
    has_phase: bool,
}

struct SimOutput {
    lines_x: i32,
    lines_y: i32,
}

#[derive(Clone, Copy)]
enum SimOutputMode {
    Immediate,
    FrameAligned { frame_ns: u64 },
}

#[derive(Default)]
struct SimRuntimeStats {
    seen: u64,
    rewritten: u64,
    passthrough: u64,
    direction_changes: u64,
}

impl AddAssign<&SimRuntimeStats> for SimRuntimeStats {
    fn add_assign(&mut self, rhs: &SimRuntimeStats) {
        self.seen += rhs.seen;
        self.rewritten += rhs.rewritten;
        self.passthrough += rhs.passthrough;
        self.direction_changes += rhs.direction_changes;
    }
}

#[derive(Default)]
struct SimDispatchStats {
    emitted_events: u64,
    emitted_inputs: u64,
    coalesced_inputs: u64,
    peak_batch_size: u64,
    total_latency_ns: u128,
    max_latency_ns: u64,
    total_abs_x: u64,
    total_abs_y: u64,
}

impl SimDispatchStats {
    fn avg_latency_ns(&self) -> f64 {
        if self.emitted_inputs == 0 {
            0.0
        } else {
            self.total_latency_ns as f64 / self.emitted_inputs as f64
        }
    }
}

impl AddAssign<&SimDispatchStats> for SimDispatchStats {
    fn add_assign(&mut self, rhs: &SimDispatchStats) {
        self.emitted_events += rhs.emitted_events;
        self.emitted_inputs += rhs.emitted_inputs;
        self.coalesced_inputs += rhs.coalesced_inputs;
        self.peak_batch_size = self.peak_batch_size.max(rhs.peak_batch_size);
        self.total_latency_ns += rhs.total_latency_ns;
        self.max_latency_ns = self.max_latency_ns.max(rhs.max_latency_ns);
        self.total_abs_x += rhs.total_abs_x;
        self.total_abs_y += rhs.total_abs_y;
    }
}

struct ScenarioReport {
    name: &'static str,
    runtime: SimRuntimeStats,
    immediate: SimDispatchStats,
    frame_aligned: SimDispatchStats,
}

struct BenchmarkCpuStats {
    elapsed_ns: u128,
    events_processed: u64,
}

#[derive(Default)]
struct BenchmarkAggregate {
    runtime: SimRuntimeStats,
    dispatch: SimDispatchStats,
}

struct TrialStats {
    min: f64,
    median: f64,
    max: f64,
}

struct HotCase {
    label: &'static str,
    workload: &'static [SimInput],
    intensity: u8,
    is_precision: u8,
}

const HOT_CASES: &[HotCase] = &[
    HotCase {
        label: "hot_rewrite     intensity=slow   precision=0",
        workload: REWRITE_WORKLOAD,
        intensity: PROBO_INTENSITY_SLOW,
        is_precision: 0,
    },
    HotCase {
        label: "hot_rewrite     intensity=slow   precision=1",
        workload: REWRITE_WORKLOAD,
        intensity: PROBO_INTENSITY_SLOW,
        is_precision: 1,
    },
    HotCase {
        label: "hot_rewrite     intensity=medium precision=0",
        workload: REWRITE_WORKLOAD,
        intensity: PROBO_INTENSITY_MEDIUM,
        is_precision: 0,
    },
    HotCase {
        label: "hot_rewrite     intensity=medium precision=1",
        workload: REWRITE_WORKLOAD,
        intensity: PROBO_INTENSITY_MEDIUM,
        is_precision: 1,
    },
    HotCase {
        label: "hot_passthrough fast  (continuous/phased)   ",
        workload: PASSTHROUGH_FAST_WORKLOAD,
        intensity: PROBO_INTENSITY_SLOW,
        is_precision: 0,
    },
    HotCase {
        label: "hot_passthrough axes  (diagonal/zero)       ",
        workload: PASSTHROUGH_AXES_WORKLOAD,
        intensity: PROBO_INTENSITY_SLOW,
        is_precision: 0,
    },
];

pub fn builtin_comparison_report(intensity: u8, frame_ns: u64) -> String {
    let reports = BUILTIN_SCENARIOS
        .iter()
        .map(|(name, inputs)| run_scenario(name, inputs, intensity, frame_ns))
        .collect::<Vec<_>>();

    render_reports(&reports, frame_ns)
}

pub fn builtin_benchmark_report(intensity: u8, frame_ns: u64, iterations: u32) -> String {
    let workload_events = BUILTIN_SCENARIOS
        .iter()
        .map(|(_, inputs)| inputs.len() as u64)
        .sum::<u64>()
        * u64::from(iterations);

    let immediate = benchmark_mode(
        BUILTIN_SCENARIOS,
        intensity,
        SimOutputMode::Immediate,
        iterations,
    );
    let frame_aligned = benchmark_mode(
        BUILTIN_SCENARIOS,
        intensity,
        SimOutputMode::FrameAligned { frame_ns },
        iterations,
    );

    let mut lines = vec![format!(
        "config iterations={} trials={} frame_aligned_period_ms={:.3} workload_events={}",
        iterations,
        HOT_TRIALS,
        ns_to_ms(frame_ns as f64),
        workload_events
    )];

    for case in HOT_CASES {
        let stats = hot_trial_stats(case.workload, case.intensity, case.is_precision, iterations);
        lines.push(format!(
            "{} ns_per_event {}",
            case.label,
            render_trial_stats(&stats)
        ));
    }

    lines.push(format!(
        "immediate cpu elapsed_ms={:.3} ns_per_event={:.2} {}",
        ns_to_ms(immediate.1.elapsed_ns as f64),
        immediate.1.elapsed_ns as f64 / immediate.1.events_processed as f64,
        render_benchmark_aggregate(&immediate.0)
    ));
    lines.push(format!(
        "frame_aligned cpu elapsed_ms={:.3} ns_per_event={:.2} {}",
        ns_to_ms(frame_aligned.1.elapsed_ns as f64),
        frame_aligned.1.elapsed_ns as f64 / frame_aligned.1.events_processed as f64,
        render_benchmark_aggregate(&frame_aligned.0)
    ));

    lines.join("\n")
}

fn render_trial_stats(stats: &TrialStats) -> String {
    format!(
        "min={:.3} median={:.3} max={:.3}",
        stats.min, stats.median, stats.max
    )
}

type Scenario = (&'static str, &'static [SimInput]);

const fn sim_tick(timestamp_ns: u64, delta_axis1: i32, delta_axis2: i32) -> SimInput {
    SimInput {
        timestamp_ns,
        delta_axis1,
        delta_axis2,
        is_continuous: false,
        has_phase: false,
    }
}

static REWRITE_WORKLOAD: &[SimInput] = &[
    sim_tick(0, 1, 0),
    sim_tick(0, -1, 0),
    sim_tick(0, 0, 1),
    sim_tick(0, 0, -1),
];

static PASSTHROUGH_FAST_WORKLOAD: &[SimInput] = &[
    SimInput {
        is_continuous: true,
        ..sim_tick(0, 1, 0)
    },
    SimInput {
        has_phase: true,
        ..sim_tick(0, 1, 0)
    },
];

static PASSTHROUGH_AXES_WORKLOAD: &[SimInput] = &[sim_tick(0, 1, 1), sim_tick(0, 0, 0)];

static BUILTIN_SCENARIOS: &[Scenario] = &[
    ("single_tick", &[sim_tick(0, 1, 0)]),
    (
        "burst_4x8ms",
        &[
            sim_tick(0, 1, 0),
            sim_tick(8_000_000, 1, 0),
            sim_tick(16_000_000, 1, 0),
            sim_tick(24_000_000, 1, 0),
        ],
    ),
    (
        "dense_8x2ms",
        &[
            sim_tick(0, 1, 0),
            sim_tick(2_000_000, 1, 0),
            sim_tick(4_000_000, 1, 0),
            sim_tick(6_000_000, 1, 0),
            sim_tick(8_000_000, 1, 0),
            sim_tick(10_000_000, 1, 0),
            sim_tick(12_000_000, 1, 0),
            sim_tick(14_000_000, 1, 0),
        ],
    ),
    (
        "direction_flip",
        &[
            sim_tick(0, 1, 0),
            sim_tick(8_000_000, 1, 0),
            sim_tick(16_000_000, -1, 0),
            sim_tick(24_000_000, -1, 0),
        ],
    ),
    (
        "horizontal_3x6ms",
        &[
            sim_tick(0, 0, 1),
            sim_tick(6_000_000, 0, 1),
            sim_tick(12_000_000, 0, 1),
        ],
    ),
    (
        "mixed_passthrough",
        &[
            sim_tick(0, 1, 0),
            SimInput {
                timestamp_ns: 5_000_000,
                delta_axis1: 1,
                delta_axis2: 1,
                is_continuous: false,
                has_phase: false,
            },
            SimInput {
                timestamp_ns: 10_000_000,
                delta_axis1: 1,
                delta_axis2: 0,
                is_continuous: true,
                has_phase: false,
            },
            sim_tick(15_000_000, 1, 0),
        ],
    ),
];

fn ffi_input(input: SimInput, intensity: u8, is_precision: u8) -> probo_wheel_input_t {
    probo_wheel_input_t {
        delta_axis1: input.delta_axis1,
        delta_axis2: input.delta_axis2,
        intensity,
        is_continuous: u8::from(input.is_continuous),
        has_phase: u8::from(input.has_phase),
        is_precision,
    }
}

fn run_scenario(
    name: &'static str,
    inputs: &[SimInput],
    intensity: u8,
    frame_ns: u64,
) -> ScenarioReport {
    let (runtime, immediate) = simulate(inputs, intensity, SimOutputMode::Immediate);
    let (_, frame_aligned) = simulate(inputs, intensity, SimOutputMode::FrameAligned { frame_ns });

    ScenarioReport {
        name,
        runtime,
        immediate,
        frame_aligned,
    }
}

fn simulate(
    inputs: &[SimInput],
    intensity: u8,
    mode: SimOutputMode,
) -> (SimRuntimeStats, SimDispatchStats) {
    let mut runtime = SimRuntimeStats::default();
    let mut dispatch = SimDispatchStats::default();
    let mut last_direction = 0;
    let mut pending = PendingBatch::default();
    let mut next_frame_ns = match mode {
        SimOutputMode::Immediate => 0,
        SimOutputMode::FrameAligned { frame_ns } => frame_ns,
    };

    for input in inputs {
        runtime.seen += 1;

        if let SimOutputMode::FrameAligned { frame_ns } = mode
            && next_frame_ns < input.timestamp_ns
        {
            if pending.count > 0 {
                flush_pending(&mut dispatch, &mut pending, next_frame_ns);
            }
            next_frame_ns = input.timestamp_ns.next_multiple_of(frame_ns);
        }

        let Some(output) = simulate_process(*input, intensity, &mut last_direction, &mut runtime)
        else {
            continue;
        };

        match mode {
            SimOutputMode::Immediate => {
                record_emit(
                    &mut dispatch,
                    1,
                    output.lines_x,
                    output.lines_y,
                    input.timestamp_ns,
                    input.timestamp_ns,
                );
            }
            SimOutputMode::FrameAligned { frame_ns } => {
                pending.add(output, input.timestamp_ns);
                if next_frame_ns <= input.timestamp_ns {
                    flush_pending(&mut dispatch, &mut pending, next_frame_ns);
                    next_frame_ns += frame_ns;
                }
            }
        }
    }

    if matches!(mode, SimOutputMode::FrameAligned { .. }) && pending.count > 0 {
        flush_pending(&mut dispatch, &mut pending, next_frame_ns);
    }

    (runtime, dispatch)
}

fn simulate_process(
    input: SimInput,
    intensity: u8,
    last_direction: &mut i32,
    runtime: &mut SimRuntimeStats,
) -> Option<SimOutput> {
    let Some(output) = process_core(ffi_input(input, intensity, 0)) else {
        runtime.passthrough += 1;
        return None;
    };

    let direction = if input.delta_axis1 != 0 {
        input.delta_axis1.signum()
    } else {
        input.delta_axis2.signum()
    };

    if *last_direction != 0 && *last_direction != direction {
        runtime.direction_changes += 1;
    }
    *last_direction = direction;
    runtime.rewritten += 1;

    Some(SimOutput {
        lines_x: output.lines_x,
        lines_y: output.lines_y,
    })
}

#[derive(Default)]
struct PendingBatch {
    count: u64,
    sum_x: i64,
    sum_y: i64,
    first_input_ns: u64,
    // sum of (timestamp_ns - first_input_ns); rebased to keep the per-input accumulator in u64.
    offset_sum_ns: u64,
}

impl PendingBatch {
    fn add(&mut self, output: SimOutput, timestamp_ns: u64) {
        if self.count == 0 {
            self.first_input_ns = timestamp_ns;
        }

        self.count += 1;
        self.sum_x += i64::from(output.lines_x);
        self.sum_y += i64::from(output.lines_y);
        self.offset_sum_ns += timestamp_ns - self.first_input_ns;
    }
}

fn flush_pending(dispatch: &mut SimDispatchStats, pending: &mut PendingBatch, emit_ns: u64) {
    if pending.count == 0 {
        return;
    }

    let batch_size = pending.count;
    let first_input_ns = pending.first_input_ns;
    record_emit(
        dispatch,
        batch_size,
        saturating_i32(pending.sum_x),
        saturating_i32(pending.sum_y),
        first_input_ns,
        emit_ns,
    );
    // promote to u128 at flush so large frame_ns * batch_size cannot overflow.
    let span = u128::from(emit_ns - first_input_ns);
    dispatch.total_latency_ns += u128::from(batch_size) * span - u128::from(pending.offset_sum_ns);

    *pending = PendingBatch::default();
}

fn record_emit(
    dispatch: &mut SimDispatchStats,
    batch_size: u64,
    lines_x: i32,
    lines_y: i32,
    first_input_ns: u64,
    emit_ns: u64,
) {
    dispatch.emitted_events += 1;
    dispatch.emitted_inputs += batch_size;
    dispatch.coalesced_inputs += batch_size.saturating_sub(1);
    dispatch.peak_batch_size = dispatch.peak_batch_size.max(batch_size);
    dispatch.max_latency_ns = dispatch.max_latency_ns.max(emit_ns - first_input_ns);
    dispatch.total_abs_x += u64::from(lines_x.unsigned_abs());
    dispatch.total_abs_y += u64::from(lines_y.unsigned_abs());
}

fn render_reports(reports: &[ScenarioReport], frame_ns: u64) -> String {
    let mut lines = vec![format!(
        "frame_aligned_period_ms={:.3}",
        ns_to_ms(frame_ns as f64)
    )];

    for report in reports {
        lines.push(String::new());
        lines.push(format!("[{}]", report.name));
        lines.push(format!(
            "runtime seen={} rewritten={} passthrough={} direction_changes={}",
            report.runtime.seen,
            report.runtime.rewritten,
            report.runtime.passthrough,
            report.runtime.direction_changes
        ));
        lines.push(format!(
            "immediate {}",
            render_dispatch_stats(&report.immediate)
        ));
        lines.push(format!(
            "frame_aligned {}",
            render_dispatch_stats(&report.frame_aligned)
        ));
    }

    lines.join("\n")
}

fn render_dispatch_stats(stats: &SimDispatchStats) -> String {
    format!(
        "events={} inputs={} coalesced={} peak_batch={} avg_latency_ms={:.3} max_latency_ms={:.3} abs_x={} abs_y={}",
        stats.emitted_events,
        stats.emitted_inputs,
        stats.coalesced_inputs,
        stats.peak_batch_size,
        ns_to_ms(stats.avg_latency_ns()),
        ns_to_ms(stats.max_latency_ns as f64),
        stats.total_abs_x,
        stats.total_abs_y
    )
}

fn hot_trial_stats(
    workload: &[SimInput],
    intensity: u8,
    is_precision: u8,
    iterations: u32,
) -> TrialStats {
    let ffi: Vec<probo_wheel_input_t> = workload
        .iter()
        .map(|input| ffi_input(*input, intensity, is_precision))
        .collect();
    let event_count = u64::from(iterations) * ffi.len() as u64;

    let mut samples: [f64; HOT_TRIALS] = std::array::from_fn(|_| {
        let opaque = black_box(ffi.as_slice());
        let start = Instant::now();
        for _ in 0..iterations {
            for input in opaque {
                black_box(probo_process_wheel(black_box(*input)));
            }
        }
        start.elapsed().as_nanos() as f64 / event_count as f64
    });
    samples.sort_unstable_by(f64::total_cmp);

    TrialStats {
        min: samples[0],
        median: samples[HOT_TRIALS / 2],
        max: samples[HOT_TRIALS - 1],
    }
}

fn benchmark_mode(
    scenarios: &[Scenario],
    intensity: u8,
    mode: SimOutputMode,
    iterations: u32,
) -> (BenchmarkAggregate, BenchmarkCpuStats) {
    let start = Instant::now();
    let mut aggregate = BenchmarkAggregate::default();
    let mut events_processed = 0_u64;

    for _ in 0..iterations {
        for &(_, inputs) in scenarios {
            let (runtime, dispatch) = simulate(inputs, intensity, mode);
            aggregate.runtime += &runtime;
            aggregate.dispatch += &dispatch;
            events_processed += inputs.len() as u64;
        }
    }

    (
        aggregate,
        BenchmarkCpuStats {
            elapsed_ns: start.elapsed().as_nanos(),
            events_processed,
        },
    )
}

fn render_benchmark_aggregate(aggregate: &BenchmarkAggregate) -> String {
    let dispatch = &aggregate.dispatch;

    format!(
        "runtime_seen={} runtime_rewritten={} passthrough={} dispatch_events={} dispatch_inputs={} coalesced={} peak_batch={} avg_latency_ms={:.3} max_latency_ms={:.3}",
        aggregate.runtime.seen,
        aggregate.runtime.rewritten,
        aggregate.runtime.passthrough,
        dispatch.emitted_events,
        dispatch.emitted_inputs,
        dispatch.coalesced_inputs,
        dispatch.peak_batch_size,
        ns_to_ms(dispatch.avg_latency_ns()),
        ns_to_ms(dispatch.max_latency_ns as f64),
    )
}

fn saturating_i32(value: i64) -> i32 {
    value.clamp(i64::from(i32::MIN), i64::from(i32::MAX)) as i32
}

fn ns_to_ms(ns: f64) -> f64 {
    ns / 1_000_000.0
}
