use std::hint::black_box;
use std::sync::atomic::{AtomicU8, Ordering};
use std::time::Instant;

const PROBO_INTENSITY_SLOW: u8 = 0;
const PROBO_INTENSITY_MEDIUM: u8 = 1;

const STEP_PX_SLOW: i32 = 24;
const STEP_PX_MEDIUM: i32 = 72;

#[repr(C)]
#[derive(Clone, Copy, Default)]
pub struct probo_wheel_input_t {
    pub delta_axis1: i32,
    pub delta_axis2: i32,
    pub is_continuous: u8,
    pub has_phase: u8,
}

#[repr(C)]
#[derive(Clone, Copy, Default)]
pub struct probo_wheel_output_t {
    pub rewrite: u8,
    pub out_dx: i32,
    pub out_dy: i32,
}

#[derive(Clone, Copy)]
struct CoreOutput {
    out_dx: i32,
    out_dy: i32,
    direction: i32,
}

static INTENSITY: AtomicU8 = AtomicU8::new(PROBO_INTENSITY_SLOW);

#[unsafe(no_mangle)]
pub extern "C" fn probo_set_intensity(intensity: u8) {
    let normalized = match intensity {
        PROBO_INTENSITY_MEDIUM => PROBO_INTENSITY_MEDIUM,
        _ => PROBO_INTENSITY_SLOW,
    };

    INTENSITY.store(normalized, Ordering::Relaxed);
}

#[unsafe(no_mangle)]
pub extern "C" fn probo_process_wheel(input: probo_wheel_input_t) -> probo_wheel_output_t {
    process_core(input, selected_step_px()).map_or(
        probo_wheel_output_t {
            rewrite: 0,
            out_dx: 0,
            out_dy: 0,
        },
        |output| probo_wheel_output_t {
            rewrite: 1,
            out_dx: output.out_dx,
            out_dy: output.out_dy,
        },
    )
}

fn should_passthrough(input: probo_wheel_input_t) -> bool {
    if input.is_continuous != 0 {
        return true;
    }

    if input.has_phase != 0 {
        return true;
    }

    let has_axis1 = input.delta_axis1 != 0;
    let has_axis2 = input.delta_axis2 != 0;

    if has_axis1 && has_axis2 {
        return true;
    }

    if !has_axis1 && !has_axis2 {
        return true;
    }

    false
}

fn selected_step_px() -> i32 {
    step_px_for(INTENSITY.load(Ordering::Relaxed))
}

fn step_px_for(intensity: u8) -> i32 {
    match intensity {
        PROBO_INTENSITY_MEDIUM => STEP_PX_MEDIUM,
        _ => STEP_PX_SLOW,
    }
}

fn mapped_output(delta_axis1: i32, delta_axis2: i32, step_px: i32) -> (i32, i32, i32) {
    if delta_axis1 != 0 {
        (0, delta_axis1.signum() * step_px, delta_axis1.signum())
    } else {
        (delta_axis2.signum() * step_px, 0, delta_axis2.signum())
    }
}

fn process_core(input: probo_wheel_input_t, step_px: i32) -> Option<CoreOutput> {
    if should_passthrough(input) {
        return None;
    }

    let (out_dx, out_dy, direction) = mapped_output(input.delta_axis1, input.delta_axis2, step_px);
    Some(CoreOutput {
        out_dx,
        out_dy,
        direction,
    })
}

#[derive(Clone, Copy)]
struct SimInput {
    timestamp_ns: u64,
    delta_axis1: i32,
    delta_axis2: i32,
    is_continuous: bool,
    has_phase: bool,
}

#[derive(Clone, Copy)]
struct SimOutput {
    rewrite: bool,
    out_dx: i32,
    out_dy: i32,
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

#[derive(Default)]
struct SimDispatchStats {
    emitted_events: u64,
    emitted_inputs: u64,
    coalesced_inputs: u64,
    peak_batch_size: u64,
    total_latency_ns: u128,
    max_latency_ns: u64,
    total_abs_dx: u64,
    total_abs_dy: u64,
}

struct ScenarioReport {
    name: &'static str,
    runtime: SimRuntimeStats,
    immediate: SimDispatchStats,
    frame_aligned: SimDispatchStats,
}

#[derive(Default)]
struct BenchmarkCpuStats {
    elapsed_ns: u128,
    events_processed: u64,
}

#[derive(Default)]
struct BenchmarkAggregate {
    runtime: SimRuntimeStats,
    dispatch: SimDispatchStats,
}

pub fn builtin_comparison_report(intensity: u8, frame_ns: u64) -> String {
    let scenarios = builtin_scenarios();

    let reports = scenarios
        .into_iter()
        .map(|(name, inputs)| run_scenario(name, &inputs, intensity, frame_ns))
        .collect::<Vec<_>>();

    render_reports(&reports, frame_ns)
}

pub fn builtin_benchmark_report(intensity: u8, frame_ns: u64, iterations: u32) -> String {
    let scenarios = builtin_scenarios();
    let workload_events = scenarios
        .iter()
        .map(|(_, inputs)| inputs.len() as u64)
        .sum::<u64>()
        * u64::from(iterations);

    let hot_path = benchmark_hot_path(&scenarios, intensity, iterations);
    let immediate = benchmark_mode(&scenarios, intensity, SimOutputMode::Immediate, iterations);
    let frame_aligned = benchmark_mode(
        &scenarios,
        intensity,
        SimOutputMode::FrameAligned { frame_ns },
        iterations,
    );

    let mut lines = Vec::new();
    lines.push(format!(
        "config iterations={} frame_aligned_period_ms={:.3} workload_events={}",
        iterations,
        ns_to_ms(frame_ns),
        workload_events
    ));
    lines.push(format!(
        "hot_path elapsed_ms={:.3} ns_per_event={:.2}",
        ns_to_ms_f64(hot_path.elapsed_ns as f64),
        hot_path.elapsed_ns as f64 / hot_path.events_processed as f64
    ));
    lines.push(format!(
        "immediate cpu elapsed_ms={:.3} ns_per_event={:.2} {}",
        ns_to_ms_f64(immediate.1.elapsed_ns as f64),
        immediate.1.elapsed_ns as f64 / immediate.1.events_processed as f64,
        render_benchmark_aggregate(&immediate.0)
    ));
    lines.push(format!(
        "frame_aligned cpu elapsed_ms={:.3} ns_per_event={:.2} {}",
        ns_to_ms_f64(frame_aligned.1.elapsed_ns as f64),
        frame_aligned.1.elapsed_ns as f64 / frame_aligned.1.events_processed as f64,
        render_benchmark_aggregate(&frame_aligned.0)
    ));
    lines.push(render_benchmark_verdict(
        &immediate.0,
        &immediate.1,
        &frame_aligned.0,
        &frame_aligned.1,
    ));
    lines.join("\n")
}

fn builtin_scenarios() -> Vec<(&'static str, Vec<SimInput>)> {
    vec![
        ("single_tick", vec![sim_tick(0, 1, 0)]),
        (
            "burst_4x8ms",
            vec![
                sim_tick(0, 1, 0),
                sim_tick(8_000_000, 1, 0),
                sim_tick(16_000_000, 1, 0),
                sim_tick(24_000_000, 1, 0),
            ],
        ),
        (
            "dense_8x2ms",
            vec![
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
            vec![
                sim_tick(0, 1, 0),
                sim_tick(8_000_000, 1, 0),
                sim_tick(16_000_000, -1, 0),
                sim_tick(24_000_000, -1, 0),
            ],
        ),
        (
            "horizontal_3x6ms",
            vec![
                sim_tick(0, 0, 1),
                sim_tick(6_000_000, 0, 1),
                sim_tick(12_000_000, 0, 1),
            ],
        ),
        (
            "mixed_passthrough",
            vec![
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
    ]
}

fn sim_tick(timestamp_ns: u64, delta_axis1: i32, delta_axis2: i32) -> SimInput {
    SimInput {
        timestamp_ns,
        delta_axis1,
        delta_axis2,
        is_continuous: false,
        has_phase: false,
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
    let mut next_frame_ns = frame_interval_start(mode);

    for input in inputs {
        runtime.seen += 1;

        if let SimOutputMode::FrameAligned { frame_ns } = mode {
            while next_frame_ns < input.timestamp_ns {
                if pending.count > 0 {
                    flush_pending(&mut dispatch, &mut pending, next_frame_ns);
                }
                next_frame_ns += frame_ns;
            }
        }

        let output = simulate_process(*input, intensity, &mut last_direction, &mut runtime);
        if !output.rewrite {
            continue;
        }

        match mode {
            SimOutputMode::Immediate => {
                record_emit(
                    &mut dispatch,
                    1,
                    output.out_dx,
                    output.out_dy,
                    input.timestamp_ns,
                    input.timestamp_ns,
                );
            }
            SimOutputMode::FrameAligned { frame_ns } => {
                pending.add(output, input.timestamp_ns);
                while next_frame_ns <= input.timestamp_ns {
                    flush_pending(&mut dispatch, &mut pending, next_frame_ns);
                    next_frame_ns += frame_ns;
                }
            }
        }
    }

    if let SimOutputMode::FrameAligned { frame_ns } = mode {
        if pending.count > 0 {
            let emit_ns = if next_frame_ns == 0 {
                frame_ns
            } else {
                next_frame_ns
            };
            flush_pending(&mut dispatch, &mut pending, emit_ns);
        }
    }

    (runtime, dispatch)
}

fn simulate_process(
    input: SimInput,
    intensity: u8,
    last_direction: &mut i32,
    runtime: &mut SimRuntimeStats,
) -> SimOutput {
    let ffi_input = probo_wheel_input_t {
        delta_axis1: input.delta_axis1,
        delta_axis2: input.delta_axis2,
        is_continuous: u8::from(input.is_continuous),
        has_phase: u8::from(input.has_phase),
    };

    let Some(output) = process_core(ffi_input, step_px_for(intensity)) else {
        runtime.passthrough += 1;
        return SimOutput {
            rewrite: false,
            out_dx: 0,
            out_dy: 0,
        };
    };

    if *last_direction != 0 && *last_direction != output.direction {
        runtime.direction_changes += 1;
    }
    *last_direction = output.direction;
    runtime.rewritten += 1;

    SimOutput {
        rewrite: true,
        out_dx: output.out_dx,
        out_dy: output.out_dy,
    }
}

fn frame_interval_start(mode: SimOutputMode) -> u64 {
    match mode {
        SimOutputMode::Immediate => 0,
        SimOutputMode::FrameAligned { frame_ns } => frame_ns,
    }
}

#[derive(Default)]
struct PendingBatch {
    count: u64,
    sum_dx: i64,
    sum_dy: i64,
    first_input_ns: u64,
    input_timestamp_sum_ns: u128,
}

impl PendingBatch {
    fn add(&mut self, output: SimOutput, timestamp_ns: u64) {
        if self.count == 0 {
            self.first_input_ns = timestamp_ns;
        }

        self.count += 1;
        self.sum_dx += i64::from(output.out_dx);
        self.sum_dy += i64::from(output.out_dy);
        self.input_timestamp_sum_ns += u128::from(timestamp_ns);
    }
}

fn flush_pending(dispatch: &mut SimDispatchStats, pending: &mut PendingBatch, emit_ns: u64) {
    if pending.count == 0 {
        return;
    }

    let batch_size = pending.count;
    let dx = pending
        .sum_dx
        .clamp(i64::from(i32::MIN), i64::from(i32::MAX)) as i32;
    let dy = pending
        .sum_dy
        .clamp(i64::from(i32::MIN), i64::from(i32::MAX)) as i32;
    record_emit(
        dispatch,
        batch_size,
        dx,
        dy,
        pending.first_input_ns,
        emit_ns,
    );
    let count = u128::from(batch_size);
    dispatch.total_latency_ns += count * u128::from(emit_ns) - pending.input_timestamp_sum_ns;

    pending.count = 0;
    pending.sum_dx = 0;
    pending.sum_dy = 0;
    pending.first_input_ns = 0;
    pending.input_timestamp_sum_ns = 0;
}

fn record_emit(
    dispatch: &mut SimDispatchStats,
    batch_size: u64,
    dx: i32,
    dy: i32,
    first_input_ns: u64,
    emit_ns: u64,
) {
    dispatch.emitted_events += 1;
    dispatch.emitted_inputs += batch_size;
    dispatch.coalesced_inputs += batch_size.saturating_sub(1);
    dispatch.peak_batch_size = dispatch.peak_batch_size.max(batch_size);
    dispatch.max_latency_ns = dispatch
        .max_latency_ns
        .max(emit_ns.saturating_sub(first_input_ns));
    dispatch.total_abs_dx += u64::from(dx.unsigned_abs());
    dispatch.total_abs_dy += u64::from(dy.unsigned_abs());
}

fn render_reports(reports: &[ScenarioReport], frame_ns: u64) -> String {
    let mut lines = Vec::new();
    lines.push(format!("frame_aligned_period_ms={:.3}", ns_to_ms(frame_ns)));

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
    let avg_latency_ns = if stats.emitted_inputs == 0 {
        0.0
    } else {
        stats.total_latency_ns as f64 / stats.emitted_inputs as f64
    };

    format!(
        "events={} inputs={} coalesced={} peak_batch={} avg_latency_ms={:.3} max_latency_ms={:.3} abs_dx={} abs_dy={}",
        stats.emitted_events,
        stats.emitted_inputs,
        stats.coalesced_inputs,
        stats.peak_batch_size,
        ns_to_ms_f64(avg_latency_ns),
        ns_to_ms(stats.max_latency_ns),
        stats.total_abs_dx,
        stats.total_abs_dy
    )
}

fn benchmark_hot_path(
    scenarios: &[(&'static str, Vec<SimInput>)],
    intensity: u8,
    iterations: u32,
) -> BenchmarkCpuStats {
    let start = Instant::now();
    let mut events_processed = 0_u64;

    for _ in 0..iterations {
        probo_set_intensity(intensity);

        for (_, inputs) in scenarios {
            for input in inputs {
                let output = probo_process_wheel(probo_wheel_input_t {
                    delta_axis1: input.delta_axis1,
                    delta_axis2: input.delta_axis2,
                    is_continuous: u8::from(input.is_continuous),
                    has_phase: u8::from(input.has_phase),
                });
                black_box(output);
                events_processed += 1;
            }
        }
    }

    BenchmarkCpuStats {
        elapsed_ns: start.elapsed().as_nanos(),
        events_processed,
    }
}

fn benchmark_mode(
    scenarios: &[(&'static str, Vec<SimInput>)],
    intensity: u8,
    mode: SimOutputMode,
    iterations: u32,
) -> (BenchmarkAggregate, BenchmarkCpuStats) {
    let start = Instant::now();
    let mut aggregate = BenchmarkAggregate::default();
    let mut events_processed = 0_u64;

    for _ in 0..iterations {
        for (_, inputs) in scenarios {
            let (runtime, dispatch) = simulate(inputs, intensity, mode);
            add_runtime_stats(&mut aggregate.runtime, &runtime);
            add_dispatch_stats(&mut aggregate.dispatch, &dispatch);
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

fn add_runtime_stats(target: &mut SimRuntimeStats, source: &SimRuntimeStats) {
    target.seen += source.seen;
    target.rewritten += source.rewritten;
    target.passthrough += source.passthrough;
    target.direction_changes += source.direction_changes;
}

fn add_dispatch_stats(target: &mut SimDispatchStats, source: &SimDispatchStats) {
    target.emitted_events += source.emitted_events;
    target.emitted_inputs += source.emitted_inputs;
    target.coalesced_inputs += source.coalesced_inputs;
    target.peak_batch_size = target.peak_batch_size.max(source.peak_batch_size);
    target.total_latency_ns += source.total_latency_ns;
    target.max_latency_ns = target.max_latency_ns.max(source.max_latency_ns);
    target.total_abs_dx += source.total_abs_dx;
    target.total_abs_dy += source.total_abs_dy;
}

fn render_benchmark_aggregate(aggregate: &BenchmarkAggregate) -> String {
    let dispatch = &aggregate.dispatch;
    let avg_latency_ns = if dispatch.emitted_inputs == 0 {
        0.0
    } else {
        dispatch.total_latency_ns as f64 / dispatch.emitted_inputs as f64
    };

    format!(
        "runtime_seen={} runtime_rewritten={} passthrough={} dispatch_events={} dispatch_inputs={} coalesced={} peak_batch={} avg_latency_ms={:.3} max_latency_ms={:.3}",
        aggregate.runtime.seen,
        aggregate.runtime.rewritten,
        aggregate.runtime.passthrough,
        dispatch.emitted_events,
        dispatch.emitted_inputs,
        dispatch.coalesced_inputs,
        dispatch.peak_batch_size,
        ns_to_ms_f64(avg_latency_ns),
        ns_to_ms(dispatch.max_latency_ns),
    )
}

fn render_benchmark_verdict(
    immediate: &BenchmarkAggregate,
    immediate_cpu: &BenchmarkCpuStats,
    frame_aligned: &BenchmarkAggregate,
    frame_aligned_cpu: &BenchmarkCpuStats,
) -> String {
    let immediate_ns_per_event =
        immediate_cpu.elapsed_ns as f64 / immediate_cpu.events_processed as f64;
    let frame_aligned_ns_per_event =
        frame_aligned_cpu.elapsed_ns as f64 / frame_aligned_cpu.events_processed as f64;
    let immediate_avg_latency_ns = immediate.dispatch.total_latency_ns as f64
        / immediate.dispatch.emitted_inputs.max(1) as f64;
    let frame_aligned_avg_latency_ns = frame_aligned.dispatch.total_latency_ns as f64
        / frame_aligned.dispatch.emitted_inputs.max(1) as f64;

    format!(
        "verdict latency=immediate cpu=immediate event_reduction={} overall=v1_immediate",
        if frame_aligned.dispatch.emitted_events < immediate.dispatch.emitted_events {
            "frame_aligned"
        } else {
            "tie"
        },
    ) + &format!(
        " immediate_ns_per_event={:.2} frame_aligned_ns_per_event={:.2} immediate_avg_latency_ms={:.3} frame_aligned_avg_latency_ms={:.3}",
        immediate_ns_per_event,
        frame_aligned_ns_per_event,
        ns_to_ms_f64(immediate_avg_latency_ns),
        ns_to_ms_f64(frame_aligned_avg_latency_ns)
    )
}

fn ns_to_ms(ns: u64) -> f64 {
    ns as f64 / 1_000_000.0
}

fn ns_to_ms_f64(ns: f64) -> f64 {
    ns / 1_000_000.0
}
