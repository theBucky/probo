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

struct BenchmarkSummary: CustomStringConvertible {
  let name: String
  let samples: [UInt64]
  let timebase: Timebase

  var description: String {
    let sorted = samples.sorted()
    let total = samples.reduce(UInt64(0), &+)
    let average = timebase.nanoseconds(total) / Double(samples.count)
    let minValue = timebase.nanoseconds(sorted[0])
    let p50 = percentile(sorted, 0.50)
    let p95 = percentile(sorted, 0.95)
    let p99 = percentile(sorted, 0.99)
    let maxValue = timebase.nanoseconds(sorted[sorted.count - 1])
    let label = String(name.prefix(26)).padding(toLength: 26, withPad: " ", startingAt: 0)

    return String(
      format: "%@ min %@  avg %@  p50 %@  p95 %@  p99 %@  max %@",
      label,
      formatNanoseconds(minValue),
      formatNanoseconds(average),
      formatNanoseconds(p50),
      formatNanoseconds(p95),
      formatNanoseconds(p99),
      formatNanoseconds(maxValue)
    )
  }

  private func percentile(_ sorted: [UInt64], _ quantile: Double) -> Double {
    let index = min(sorted.count - 1, Int(Double(sorted.count - 1) * quantile))
    return timebase.nanoseconds(sorted[index])
  }
}

func measure(
  _ name: String,
  options: ProfileOptions,
  timebase: Timebase,
  blackhole: inout Int64,
  prepare: () -> Void = {},
  operation: () -> Int64
) -> BenchmarkSummary {
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

  return BenchmarkSummary(name: name, samples: samples, timebase: timebase)
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
