@preconcurrency import ApplicationServices

// Hot path: one wheel notch per call, no allocation, lock, or lookup.
package final class ScrollRewriter {
  private static let pixelsPerLine: Int64 = 16

  private let optionStrip: OptionStrip?

  package init() {
    let source = CGEventSource(stateID: .hidSystemState)
    source?.pixelsPerLine = Double(Self.pixelsPerLine)
    optionStrip = OptionStrip(source: source)
  }

  package func rewrite(
    _ event: CGEvent,
    configuration: InputConfiguration,
    isTerminalFrontmost: Bool
  ) -> ScrollRewrite {
    guard Self.isWheelNotchEvent(event) else { return .deliver(event) }
    guard
      let notch = WheelNotch(
        verticalDelta: Int32(
          truncatingIfNeeded: event.getIntegerValueField(.scrollWheelEventDeltaAxis1)
        ),
        horizontalDelta: Int32(
          truncatingIfNeeded: event.getIntegerValueField(.scrollWheelEventDeltaAxis2)
        )
      )
    else { return .drop }

    let step = configuration.scrollStep(
      for: notch,
      isOptionHeld: event.flags.contains(.maskAlternate),
      isTerminalFrontmost: isTerminalFrontmost
    )
    guard step.stripsOption else {
      Self.write(step, to: event)
      return .deliver(event)
    }

    // Without synthesized events, dropping beats delivering an Option-bearing notch that terminals read as alt-scroll.
    guard let optionStrip else { return .drop }
    return .post(optionStrip.strip(step, from: event))
  }

  // Trackpad and Magic Mouse scrolling is continuous or phased; wheel notches are neither.
  private static func isWheelNotchEvent(_ event: CGEvent) -> Bool {
    if event.getIntegerValueField(.scrollWheelEventIsContinuous) != 0 { return false }
    if event.getIntegerValueField(.scrollWheelEventScrollPhase) != 0 { return false }
    if event.getIntegerValueField(.scrollWheelEventMomentumPhase) != 0 { return false }
    let subtype = CGEventMouseSubtype(
      rawValue: UInt32(event.getIntegerValueField(.mouseEventSubtype)))
    if subtype != .defaultType { return false }
    return event.getIntegerValueField(.tabletEventDeviceID) == 0
  }

  fileprivate static func write(_ step: ScrollStep, to event: CGEvent) {
    let linesY: Int64 = step.axis == .vertical ? Int64(step.lines) : 0
    let linesX: Int64 = step.axis == .horizontal ? Int64(step.lines) : 0
    event.setIntegerValueField(.scrollWheelEventDeltaAxis1, value: linesY)
    event.setIntegerValueField(.scrollWheelEventDeltaAxis2, value: linesX)
    event.setIntegerValueField(.scrollWheelEventDeltaAxis3, value: 0)
    event.setIntegerValueField(.scrollWheelEventFixedPtDeltaAxis1, value: linesY * 65_536)
    event.setIntegerValueField(.scrollWheelEventFixedPtDeltaAxis2, value: linesX * 65_536)
    event.setIntegerValueField(.scrollWheelEventFixedPtDeltaAxis3, value: 0)
    event.setIntegerValueField(.scrollWheelEventPointDeltaAxis1, value: linesY * pixelsPerLine)
    event.setIntegerValueField(.scrollWheelEventPointDeltaAxis2, value: linesX * pixelsPerLine)
    event.setIntegerValueField(.scrollWheelEventPointDeltaAxis3, value: 0)
    event.setIntegerValueField(.scrollWheelEventScrollCount, value: 1)
    event.setIntegerValueField(.scrollWheelEventIsContinuous, value: 0)
    event.setIntegerValueField(.scrollWheelEventScrollPhase, value: 0)
    event.setIntegerValueField(.scrollWheelEventMomentumPhase, value: 0)
  }
}

package enum ScrollRewrite {
  case deliver(CGEvent)
  case drop
  case post(StrippedNotch)
}

// An Option-free notch between flagsChanged release and restore. Returning the notch from the tap would deliver it after both posted flag events, so all three are posted and the original is dropped.
package struct StrippedNotch {
  let optionReleased: CGEvent
  let notch: CGEvent
  let optionRestored: CGEvent

  func post(via proxy: CGEventTapProxy) {
    optionReleased.tapPostEvent(proxy)
    notch.tapPostEvent(proxy)
    optionRestored.tapPostEvent(proxy)
  }
}

private struct OptionStrip {
  private static let leftOptionFlag = CGEventFlags(rawValue: 0x20)
  private static let rightOptionFlag = CGEventFlags(rawValue: 0x40)
  private static let allOptionFlags: CGEventFlags = [
    .maskAlternate, leftOptionFlag, rightOptionFlag,
  ]
  private static let leftOptionKey = CGKeyCode(0x3A)
  private static let rightOptionKey = CGKeyCode(0x3D)

  private let vertical: CGEvent
  private let horizontal: CGEvent
  private let optionReleased: CGEvent
  private let optionRestored: CGEvent

  init?(source: CGEventSource?) {
    guard
      let vertical = CGEvent(
        scrollWheelEvent2Source: source, units: .line, wheelCount: 1,
        wheel1: 0, wheel2: 0, wheel3: 0
      ),
      let horizontal = CGEvent(
        scrollWheelEvent2Source: source, units: .line, wheelCount: 2,
        wheel1: 0, wheel2: 0, wheel3: 0
      ),
      let optionReleased = CGEvent(source: source),
      let optionRestored = CGEvent(source: source)
    else { return nil }
    optionReleased.type = .flagsChanged
    optionRestored.type = .flagsChanged
    self.vertical = vertical
    self.horizontal = horizontal
    self.optionReleased = optionReleased
    self.optionRestored = optionRestored
  }

  func strip(_ step: ScrollStep, from event: CGEvent) -> StrippedNotch {
    let originalFlags = event.flags
    let strippedFlags = originalFlags.subtracting(Self.allOptionFlags)
    let optionKey = Int64(
      originalFlags.contains(Self.rightOptionFlag) ? Self.rightOptionKey : Self.leftOptionKey
    )

    let notch = step.axis == .vertical ? vertical : horizontal
    notch.location = event.location
    notch.flags = strippedFlags
    notch.timestamp = event.timestamp
    ScrollRewriter.write(step, to: notch)

    optionReleased.flags = strippedFlags
    optionReleased.timestamp = event.timestamp
    optionReleased.setIntegerValueField(.keyboardEventKeycode, value: optionKey)
    optionRestored.flags = originalFlags
    optionRestored.timestamp = event.timestamp
    optionRestored.setIntegerValueField(.keyboardEventKeycode, value: optionKey)
    return StrippedNotch(
      optionReleased: optionReleased, notch: notch, optionRestored: optionRestored)
  }
}
