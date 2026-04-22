use probo_runtime::builtin_comparison_report;

fn main() {
    println!("{}", builtin_comparison_report(0, 1_000_000_000 / 120));
}
