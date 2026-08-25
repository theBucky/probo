import ApplicationServices
import Darwin
import Foundation
import ProboCore

@main
struct HotPathProfile {
  static func main() throws {
    let options = try ProfileOptions.parse()
    let timebase = Timebase()
    let source = CGEventSource(stateID: .hidSystemState)
    source?.pixelsPerLine = 16.0

    guard let event = makeInputEvent(source: source, verticalDelta: 1, horizontalDelta: 0) else {
      throw ProfileError("failed to create synthetic scroll event")
    }

    let tapOptions = TapOptions(configuration: InputConfiguration())
    let tapOptionsRawValue = tapOptions.rawValue
    let rewriter = ScrollRewriter(isTerminalFrontmost: { false })
    guard
      case .vertical(let linesY, _) = resolveScroll(
        .vertical(.positive),
        isOptionHeld: false,
        isTerminalFrontmost: false,
        options: tapOptions
      )
    else {
      throw ProfileError("vertical input resolved to horizontal output")
    }
    let resetEvent = { rewriter.applyReplacement(to: event, linesX: 0, linesY: 1) }
    var blackhole: Int64 = 0

    Swift.print("synthetic input: discrete line-unit CGEvent, no HID driver, no device coalescing")
    Swift.print(
      "iterations: \(options.benchmark.iterations), warmup: \(options.benchmark.warmup)"
    )
    Swift.print("")

    print(
      measure(
        "timer baseline",
        options: options.benchmark,
        timebase: timebase,
        blackhole: &blackhole
      ) {
        1
      }
    )

    print(
      measure(
        "core only",
        options: options.benchmark,
        timebase: timebase,
        blackhole: &blackhole
      ) {
        switch resolveScroll(
          .vertical(.positive),
          isOptionHeld: false,
          isTerminalFrontmost: false,
          options: tapOptions
        ) {
        case .vertical(let lines, _): Int64(lines)
        case .horizontal: 0
        }
      }
    )

    print(
      measure(
        "synth make event",
        options: options.benchmark,
        timebase: timebase,
        blackhole: &blackhole,
        prepare: resetEvent
      ) {
        guard
          let replacement = rewriter.makeReplacement(
            location: event.location,
            flags: event.flags,
            linesX: 0,
            linesY: linesY
          )
        else { return 0 }
        return replacement.getIntegerValueField(.scrollWheelEventDeltaAxis1)
      }
    )

    print(
      measure(
        "apply replacement",
        options: options.benchmark,
        timebase: timebase,
        blackhole: &blackhole,
        prepare: resetEvent
      ) {
        rewriter.applyReplacement(to: event, linesX: 0, linesY: linesY)
        return event.getIntegerValueField(.scrollWheelEventDeltaAxis1)
      }
    )

    print(
      measure(
        "options decode",
        options: options.benchmark,
        timebase: timebase,
        blackhole: &blackhole
      ) {
        let decoded = TapOptions(rawValue: tapOptionsRawValue)
        return decoded.isTerminalOptimizationEnabled ? 1 : 0
      }
    )

    print(
      measure(
        "rewriter mutate",
        options: options.benchmark,
        timebase: timebase,
        blackhole: &blackhole,
        prepare: resetEvent
      ) {
        rewriter.rewrite(event: event, options: tapOptions, proxy: nil)?
          .getIntegerValueField(.scrollWheelEventDeltaAxis1) ?? 0
      }
    )

    print(
      measure(
        "rewriter + decode",
        options: options.benchmark,
        timebase: timebase,
        blackhole: &blackhole,
        prepare: resetEvent
      ) {
        let decoded = TapOptions(rawValue: tapOptionsRawValue)
        return rewriter.rewrite(event: event, options: decoded, proxy: nil)?
          .getIntegerValueField(.scrollWheelEventDeltaAxis1) ?? 0
      }
    )

    if let eventPosting = options.eventPosting {
      try postInputEvents(options: eventPosting, source: source)
    }

    Swift.print("")
    Swift.print("blackhole: \(blackhole)")
  }
}

private func makeInputEvent(
  source: CGEventSource?,
  verticalDelta: Int32,
  horizontalDelta: Int32
) -> CGEvent? {
  guard
    let event = CGEvent(
      scrollWheelEvent2Source: source,
      units: .line,
      wheelCount: horizontalDelta == 0 ? 1 : 2,
      wheel1: verticalDelta,
      wheel2: horizontalDelta,
      wheel3: 0
    )
  else {
    return nil
  }

  event.location = CGPoint(x: 100, y: 100)
  event.setIntegerValueField(.scrollWheelEventScrollCount, value: 1)
  return event
}

private func postInputEvents(options: EventPostingOptions, source: CGEventSource?) throws {
  Swift.print("")
  Swift.print(
    "posting \(options.count) synthetic scroll events to cgSessionEventTap"
  )

  for index in 0..<options.count {
    guard
      let event = makeInputEvent(
        source: source, verticalDelta: index.isMultiple(of: 2) ? 1 : -1, horizontalDelta: 0)
    else {
      throw ProfileError("failed to create post event")
    }
    event.post(tap: .cgSessionEventTap)
    if options.intervalUsec > 0 {
      usleep(options.intervalUsec)
    }
  }
}
