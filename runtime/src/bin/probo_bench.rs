use std::env;

use probo_runtime::builtin_benchmark_report;

fn main() {
    let iterations = env::args()
        .nth(1)
        .and_then(|value| value.parse::<u32>().ok())
        .unwrap_or(100_000);

    println!(
        "{}",
        builtin_benchmark_report(0, 1_000_000_000 / 120, iterations)
    );
}
