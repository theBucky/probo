import ApplicationServices
import Darwin
import Foundation
import ProboCore

private struct Options {
  var iterations = 100_000
  var warmup = 10_000
  var postEvents = 0
  var postIntervalUsec: UInt32 = 0
}

private struct Timebase {
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

private struct Summary {
  var name: String
  var samples: [UInt64]
  var timebase: Timebase

  func print() {
    let sorted = samples.sorted()
    let total = samples.reduce(UInt64(0), &+)
    let average = timebase.nanoseconds(total) / Double(samples.count)
    let minValue = timebase.nanoseconds(sorted[0])
    let p50 = percentile(sorted, 0.50)
    let p95 = percentile(sorted, 0.95)
    let p99 = percentile(sorted, 0.99)
    let maxValue = timebase.nanoseconds(sorted[sorted.count - 1])
    let label = String(name.prefix(26)).padding(toLength: 26, withPad: " ", startingAt: 0)

    Swift.print(
      String(
        format: "%@ min %@  avg %@  p50 %@  p95 %@  p99 %@  max %@",
        label,
        formatNanoseconds(minValue),
        formatNanoseconds(average),
        formatNanoseconds(p50),
        formatNanoseconds(p95),
        formatNanoseconds(p99),
        formatNanoseconds(maxValue)
      )
    )
  }

  private func percentile(_ sorted: [UInt64], _ quantile: Double) -> Double {
    let index = min(sorted.count - 1, Int(Double(sorted.count - 1) * quantile))
    return timebase.nanoseconds(sorted[index])
  }
}

@main
struct HotPathProfile {
  static func main() throws {
    let options = try parseOptions()
    let timebase = Timebase()
    let source = CGEventSource(stateID: .hidSystemState)
    source?.pixelsPerLine = 16.0

    guard let event = makeInputEvent(source: source, verticalDelta: 1, horizontalDelta: 0) else {
      throw ProbeError.message("failed to create synthetic scroll event")
    }

    let configuration = AppConfiguration()
    let tapOptions = EventTapOptions(configuration: configuration)
    let tapOptionsRawValue = tapOptions.rawValue
    let synth = ScrollEventSynthesizer()
    let rewriter = ScrollEventRewriter(isTerminalFrontmost: { false })
    let linesY = ScrollRewriteCore.rewrite(
      verticalDelta: 1,
      horizontalDelta: 0,
      intensity: configuration.intensity,
      isContinuous: false,
      hasPhase: false,
      isPrecision: false,
      isTrackpadStyleScrollingEnabled: configuration.isTrackpadStyleScrollingEnabled
    )!.linesY
    let resetEvent = { resetInputEvent(event, synth: synth) }
    var blackhole: Int64 = 0

    Swift.print("synthetic input: discrete line-unit CGEvent, no HID driver, no device coalescing")
    Swift.print("iterations: \(options.iterations), warmup: \(options.warmup)")
    Swift.print("")

    measure(
      "timer baseline",
      options: options,
      timebase: timebase,
      blackhole: &blackhole
    ) {
      1
    }.print()

    measure(
      "core only",
      options: options,
      timebase: timebase,
      blackhole: &blackhole
    ) {
      guard
        let (_, linesY) = ScrollRewriteCore.rewrite(
          verticalDelta: 1,
          horizontalDelta: 0,
          intensity: configuration.intensity,
          isContinuous: false,
          hasPhase: false,
          isPrecision: false,
          isTrackpadStyleScrollingEnabled: configuration.isTrackpadStyleScrollingEnabled
        )
      else { return 0 }
      return Int64(linesY)
    }.print()

    measure(
      "synth make event",
      options: options,
      timebase: timebase,
      blackhole: &blackhole,
      prepare: resetEvent
    ) {
      guard
        let replacement = synth.makeReplacement(
          location: event.location,
          flags: event.flags,
          linesX: 0,
          linesY: linesY
        )
      else { return 0 }
      return replacement.getIntegerValueField(.scrollWheelEventDeltaAxis1)
    }.print()

    measure(
      "apply replacement",
      options: options,
      timebase: timebase,
      blackhole: &blackhole,
      prepare: resetEvent
    ) {
      synth.applyReplacement(to: event, linesX: 0, linesY: linesY)
      return event.getIntegerValueField(.scrollWheelEventDeltaAxis1)
    }.print()

    measure(
      "options decode",
      options: options,
      timebase: timebase,
      blackhole: &blackhole
    ) {
      let decoded = EventTapOptions(rawValue: tapOptionsRawValue)
      return decoded.isTerminalOptimizationEnabled ? 1 : 0
    }.print()

    measure(
      "rewriter mutate",
      options: options,
      timebase: timebase,
      blackhole: &blackhole,
      prepare: resetEvent
    ) {
      rewriter.rewrite(event: event, options: tapOptions)?
        .getIntegerValueField(.scrollWheelEventDeltaAxis1) ?? 0
    }.print()

    measure(
      "rewriter + decode",
      options: options,
      timebase: timebase,
      blackhole: &blackhole,
      prepare: resetEvent
    ) {
      let decoded = EventTapOptions(rawValue: tapOptionsRawValue)
      return rewriter.rewrite(event: event, options: decoded)?
        .getIntegerValueField(.scrollWheelEventDeltaAxis1) ?? 0
    }.print()

    if options.postEvents > 0 {
      try postInputEvents(options: options, source: source)
    }

    Swift.print("")
    Swift.print("blackhole: \(blackhole)")
  }
}

private func parseOptions() throws -> Options {
  var options = Options()
  var arguments = CommandLine.arguments.dropFirst()

  while let argument = arguments.popFirst() {
    switch argument {
    case "--iterations":
      options.iterations = try takePositiveInt(&arguments, argument)
    case "--warmup":
      options.warmup = try takeNonNegativeInt(&arguments, argument)
    case "--post-events":
      options.postEvents = try takeNonNegativeInt(&arguments, argument)
    case "--post-interval-usec":
      options.postIntervalUsec = try takeUInt32(&arguments, argument)
    case "-h", "--help":
      Swift.print(
        """
        usage: HotPathProfile [options]

          --iterations n            measured samples per stage, default 100000
          --warmup n                warmup iterations per stage, default 10000
          --post-events n           post n unmarked synthetic scroll events to cgSessionEventTap
          --post-interval-usec n    sleep between posted events
        """
      )
      exit(0)
    default:
      throw ProbeError.message("unknown option: \(argument)")
    }
  }

  return options
}

private func takeUInt32(_ arguments: inout ArraySlice<String>, _ name: String) throws -> UInt32 {
  let value = try takeNonNegativeInt(&arguments, name)
  guard value <= UInt32.max else {
    throw ProbeError.message("\(name) must fit UInt32")
  }
  return UInt32(value)
}

private func takePositiveInt(_ arguments: inout ArraySlice<String>, _ name: String) throws -> Int {
  let value = try takeNonNegativeInt(&arguments, name)
  if value <= 0 {
    throw ProbeError.message("\(name) must be positive")
  }
  return value
}

private func takeNonNegativeInt(_ arguments: inout ArraySlice<String>, _ name: String) throws -> Int
{
  guard let rawValue = arguments.popFirst() else {
    throw ProbeError.message("missing value for \(name)")
  }
  guard let value = Int(rawValue), value >= 0 else {
    throw ProbeError.message("\(name) must be a non-negative integer")
  }
  return value
}

private func measure(
  _ name: String,
  options: Options,
  timebase: Timebase,
  blackhole: inout Int64,
  prepare: () -> Void = {},
  operation: () -> Int64
) -> Summary {
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

  return Summary(name: name, samples: samples, timebase: timebase)
}

private func makeInputEvent(
  source: CGEventSource?,
  verticalDelta: Int32,
  horizontalDelta: Int32
) -> CGEvent? {
  let wheelCount: UInt32 = horizontalDelta == 0 ? 1 : 2
  guard
    let event = CGEvent(
      scrollWheelEvent2Source: source,
      units: .line,
      wheelCount: wheelCount,
      wheel1: verticalDelta,
      wheel2: horizontalDelta,
      wheel3: 0
    )
  else {
    return nil
  }

  event.location = CGPoint(x: 100, y: 100)
  event.setIntegerValueField(.scrollWheelEventScrollCount, value: 1)
  event.setIntegerValueField(.eventSourceUserData, value: 0)
  return event
}

private func resetInputEvent(_ event: CGEvent, synth: ScrollEventSynthesizer) {
  synth.applyReplacement(to: event, linesX: 0, linesY: 1)
  event.setIntegerValueField(.eventSourceUserData, value: 0)
}

private func postInputEvents(options: Options, source: CGEventSource?) throws {
  Swift.print("")
  Swift.print(
    "posting \(options.postEvents) unmarked synthetic scroll events to cgSessionEventTap"
  )

  for index in 0..<options.postEvents {
    guard
      let event = makeInputEvent(
        source: source, verticalDelta: index.isMultiple(of: 2) ? 1 : -1, horizontalDelta: 0)
    else {
      throw ProbeError.message("failed to create post event")
    }
    event.post(tap: .cgSessionEventTap)
    if options.postIntervalUsec > 0 {
      usleep(options.postIntervalUsec)
    }
  }
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

private enum ProbeError: Error, CustomStringConvertible {
  case message(String)

  var description: String {
    switch self {
    case .message(let message):
      return message
    }
  }
}
