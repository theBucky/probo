#[cfg(feature = "sim")]
mod sim;

#[cfg(feature = "sim")]
pub use sim::{builtin_benchmark_report, builtin_comparison_report};

const PROBO_INTENSITY_MEDIUM: u8 = 1;

const STEP_LINES_SLOW: i32 = 2;
const STEP_LINES_MEDIUM: i32 = 4;

#[repr(C)]
#[derive(Clone, Copy)]
pub struct probo_wheel_input_t {
    pub delta_axis1: i32,
    pub delta_axis2: i32,
    pub intensity: u8,
    pub is_continuous: u8,
    pub has_phase: u8,
}

#[repr(C)]
#[derive(Default)]
pub struct probo_wheel_output_t {
    pub rewrite: u8,
    pub out_lines_x: i32,
    pub out_lines_y: i32,
}

pub(crate) struct CoreOutput {
    pub lines_x: i32,
    pub lines_y: i32,
}

#[unsafe(no_mangle)]
pub extern "C" fn probo_process_wheel(input: probo_wheel_input_t) -> probo_wheel_output_t {
    match process_core(input) {
        None => probo_wheel_output_t::default(),
        Some(output) => probo_wheel_output_t {
            rewrite: 1,
            out_lines_x: output.lines_x,
            out_lines_y: output.lines_y,
        },
    }
}

pub(crate) fn process_core(input: probo_wheel_input_t) -> Option<CoreOutput> {
    if should_passthrough(input) {
        return None;
    }

    Some(mapped_output(
        input.delta_axis1,
        input.delta_axis2,
        step_lines_for(input.intensity),
    ))
}

fn should_passthrough(input: probo_wheel_input_t) -> bool {
    input.is_continuous != 0
        || input.has_phase != 0
        || (input.delta_axis1 != 0) == (input.delta_axis2 != 0)
}

fn step_lines_for(intensity: u8) -> i32 {
    match intensity {
        PROBO_INTENSITY_MEDIUM => STEP_LINES_MEDIUM,
        _ => STEP_LINES_SLOW,
    }
}

fn mapped_output(delta_axis1: i32, delta_axis2: i32, step_lines: i32) -> CoreOutput {
    // passthrough guarantees exactly one axis is nonzero; the other signum is 0.
    CoreOutput {
        lines_x: delta_axis2.signum() * step_lines,
        lines_y: delta_axis1.signum() * step_lines,
    }
}
