import ApplicationServices
import Darwin
import Foundation
import ProboCore
import Synchronization

@main
struct HotPathProfile {
  static func main() throws {
    let options = try ProfileOptions.parse()
    let timebase = Timebase()
    let source = CGEventSource(stateID: .hidSystemState)
    source?.pixelsPerLine = 16.0

    guard let event = makeInputEvent(source: source, verticalDelta: 1) else {
      throw ProfileError("failed to create synthetic scroll event")
    }

    let configuration = InputConfiguration()
    let published = Atomic<InputConfiguration>(configuration)
    let rewriter = ScrollRewriter()
    let notch = WheelNotch(axis: .vertical, direction: .positive)
    let resetEvent = { event.setIntegerValueField(.scrollWheelEventDeltaAxis1, value: 1) }
    var blackhole: Int64 = 0

    print("synthetic input: discrete line-unit CGEvent, no HID driver, no device coalescing")
    print("iterations: \(options.benchmark.iterations), warmup: \(options.benchmark.warmup)")
    print("")

    print(
      measure(
        "timer baseline", options: options.benchmark, timebase: timebase, blackhole: &blackhole
      ) {
        1
      }
    )

    print(
      measure(
        "scroll policy", options: options.benchmark, timebase: timebase, blackhole: &blackhole
      ) {
        Int64(
          configuration.scrollStep(for: notch, isOptionHeld: false, isTerminalFrontmost: false)
            .lines
        )
      }
    )

    print(
      measure(
        "configuration load", options: options.benchmark, timebase: timebase,
        blackhole: &blackhole
      ) {
        published.load(ordering: .relaxed).isTerminalOptimizationEnabled ? 1 : 0
      }
    )

    print(
      measure(
        "rewrite in place", options: options.benchmark, timebase: timebase, blackhole: &blackhole,
        prepare: resetEvent
      ) {
        _ = rewriter.rewrite(event, configuration: configuration, isTerminalFrontmost: false)
        return event.getIntegerValueField(.scrollWheelEventDeltaAxis1)
      }
    )

    print(
      measure(
        "load + rewrite", options: options.benchmark, timebase: timebase, blackhole: &blackhole,
        prepare: resetEvent
      ) {
        _ = rewriter.rewrite(
          event, configuration: published.load(ordering: .relaxed), isTerminalFrontmost: false)
        return event.getIntegerValueField(.scrollWheelEventDeltaAxis1)
      }
    )

    if let eventPosting = options.eventPosting {
      try postInputEvents(options: eventPosting, source: source)
    }

    print("")
    print("blackhole: \(blackhole)")
  }
}

private func makeInputEvent(source: CGEventSource?, verticalDelta: Int32) -> CGEvent? {
  guard
    let event = CGEvent(
      scrollWheelEvent2Source: source,
      units: .line,
      wheelCount: 1,
      wheel1: verticalDelta,
      wheel2: 0,
      wheel3: 0
    )
  else { return nil }
  event.location = CGPoint(x: 100, y: 100)
  event.setIntegerValueField(.scrollWheelEventScrollCount, value: 1)
  return event
}

private func postInputEvents(options: EventPostingOptions, source: CGEventSource?) throws {
  print("")
  print("posting \(options.count) synthetic scroll events to cgSessionEventTap")

  for index in 0..<options.count {
    guard
      let event = makeInputEvent(source: source, verticalDelta: index.isMultiple(of: 2) ? 1 : -1)
    else {
      throw ProfileError("failed to create post event")
    }
    event.post(tap: .cgSessionEventTap)
    if options.intervalUsec > 0 {
      usleep(options.intervalUsec)
    }
  }
}
