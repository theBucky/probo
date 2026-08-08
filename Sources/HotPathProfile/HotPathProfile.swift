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

    let configuration = AppConfiguration()
    let tapOptions = TapOptions(configuration: configuration)
    let tapOptionsRawValue = tapOptions.rawValue
    let rewriter = ScrollRewriter(isTerminalFrontmost: { false })
    guard
      case .emit(_, let linesY, _) = decideScroll(
        verticalDelta: 1,
        horizontalDelta: 0,
        isOptionHeld: false,
        isTerminalFrontmost: false,
        options: tapOptions
      )
    else {
      throw ProfileError("default configuration must rewrite a vertical notch")
    }
    let resetEvent = { rewriter.applyReplacement(to: event, linesX: 0, linesY: 1) }
    var blackhole: Int64 = 0

    Swift.print("synthetic input: discrete line-unit CGEvent, no HID driver, no device coalescing")
    Swift.print("iterations: \(options.iterations), warmup: \(options.warmup)")
    Swift.print("")

    print(
      measure(
        "timer baseline",
        options: options,
        timebase: timebase,
        blackhole: &blackhole
      ) {
        1
      }
    )

    print(
      measure(
        "core only",
        options: options,
        timebase: timebase,
        blackhole: &blackhole
      ) {
        guard
          case .emit(_, let linesY, _) = decideScroll(
            verticalDelta: 1,
            horizontalDelta: 0,
            isOptionHeld: false,
            isTerminalFrontmost: false,
            options: tapOptions
          )
        else { return 0 }
        return Int64(linesY)
      }
    )

    print(
      measure(
        "synth make event",
        options: options,
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
        options: options,
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
        options: options,
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
        options: options,
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
        options: options,
        timebase: timebase,
        blackhole: &blackhole,
        prepare: resetEvent
      ) {
        let decoded = TapOptions(rawValue: tapOptionsRawValue)
        return rewriter.rewrite(event: event, options: decoded, proxy: nil)?
          .getIntegerValueField(.scrollWheelEventDeltaAxis1) ?? 0
      }
    )

    if options.postEvents > 0 {
      try postInputEvents(options: options, source: source)
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
  return event
}

private func postInputEvents(options: ProfileOptions, source: CGEventSource?) throws {
  Swift.print("")
  Swift.print(
    "posting \(options.postEvents) synthetic scroll events to cgSessionEventTap"
  )

  for index in 0..<options.postEvents {
    guard
      let event = makeInputEvent(
        source: source, verticalDelta: index.isMultiple(of: 2) ? 1 : -1, horizontalDelta: 0)
    else {
      throw ProfileError("failed to create post event")
    }
    event.post(tap: .cgSessionEventTap)
    if options.postIntervalUsec > 0 {
      usleep(options.postIntervalUsec)
    }
  }
}
