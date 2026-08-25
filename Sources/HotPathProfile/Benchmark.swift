import Darwin
import Foundation

struct Timebase {
  let numer: UInt32
  let denom: UInt32

  init() {
    var info = mach_timebase_info_data_t()
    mach_timebase_info(&info)
    numer = info.numer
    denom = info.denom
  }

  func nanoseconds(_ ticks: UInt64) -> Double {
    Double(ticks) * Double(numer) / Double(denom)
  }
}

func measure(
  _ name: String,
  options: BenchmarkOptions,
  timebase: Timebase,
  blackhole: inout Int64,
  prepare: () -> Void = {},
  operation: () -> Int64
) -> String {
  for _ in 0..<options.warmup {
    prepare()
    blackhole &+= operation()
  }

  var samples = [UInt64](repeating: 0, count: options.iterations)
  for index in 0..<options.iterations {
    prepare()
    let start = mach_continuous_time()
    blackhole &+= operation()
    samples[index] = mach_continuous_time() - start
  }

  let sorted = samples.sorted()
  func percentile(_ quantile: Double) -> Double {
    let index = min(sorted.count - 1, Int(Double(sorted.count - 1) * quantile))
    return timebase.nanoseconds(sorted[index])
  }

  let average = timebase.nanoseconds(samples.reduce(UInt64(0), &+)) / Double(samples.count)
  let label = String(name.prefix(26)).padding(toLength: 26, withPad: " ", startingAt: 0)
  return String(
    format: "%@ min %@  avg %@  p50 %@  p95 %@  p99 %@  max %@",
    label,
    formatNanoseconds(timebase.nanoseconds(sorted[0])),
    formatNanoseconds(average),
    formatNanoseconds(percentile(0.50)),
    formatNanoseconds(percentile(0.95)),
    formatNanoseconds(percentile(0.99)),
    formatNanoseconds(timebase.nanoseconds(sorted[sorted.count - 1]))
  )
}

private func formatNanoseconds(_ value: Double) -> String {
  if value < 1_000 {
    return String(format: "%.0f ns", value)
  }
  if value < 1_000_000 {
    return String(format: "%.2f us", value / 1_000)
  }
  return String(format: "%.2f ms", value / 1_000_000)
}
