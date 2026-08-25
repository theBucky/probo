@preconcurrency import ApplicationServices

package final class ScrollRewriter {
  private static let pixelsPerLine: Int64 = 16
  private static let leftOptionFlag = CGEventFlags(rawValue: 0x20)
  private static let rightOptionFlag = CGEventFlags(rawValue: 0x40)
  private static let allOptionFlags: CGEventFlags = [
    .maskAlternate, leftOptionFlag, rightOptionFlag,
  ]
  private static let leftOptionKey = CGKeyCode(0x3A)
  private static let rightOptionKey = CGKeyCode(0x3D)

  private let isTerminalFrontmost: @Sendable () -> Bool
  private let source: CGEventSource?
  private let strippedEvents:
    (
      vertical: CGEvent,
      horizontal: CGEvent,
      optionReleased: CGEvent,
      optionRestored: CGEvent
    )?

  package init(isTerminalFrontmost: @escaping @Sendable () -> Bool) {
    let source = CGEventSource(stateID: .hidSystemState)
    source?.pixelsPerLine = Double(Self.pixelsPerLine)

    self.isTerminalFrontmost = isTerminalFrontmost
    self.source = source
    if let vertical = CGEvent(
      scrollWheelEvent2Source: source,
      units: .line,
      wheelCount: 1,
      wheel1: 0,
      wheel2: 0,
      wheel3: 0
    ),
      let horizontal = CGEvent(
        scrollWheelEvent2Source: source,
        units: .line,
        wheelCount: 2,
        wheel1: 0,
        wheel2: 0,
        wheel3: 0
      ),
      let optionReleased = CGEvent(source: source),
      let optionRestored = CGEvent(source: source)
    {
      optionReleased.type = .flagsChanged
      optionRestored.type = .flagsChanged
      strippedEvents = (vertical, horizontal, optionReleased, optionRestored)
    } else {
      strippedEvents = nil
    }
  }

  package func rewrite(event: CGEvent, options: TapOptions, proxy: CGEventTapProxy?) -> CGEvent? {
    guard Self.isDiscreteWheelEvent(event) else { return event }

    guard
      let notch = WheelNotch(
        verticalDelta: Int32(
          truncatingIfNeeded: event.getIntegerValueField(.scrollWheelEventDeltaAxis1)
        ),
        horizontalDelta: Int32(
          truncatingIfNeeded: event.getIntegerValueField(.scrollWheelEventDeltaAxis2)
        )
      )
    else { return nil }

    let originalFlags = event.flags
    let (linesX, linesY, stripsOption, strippedReplacement): (Int32, Int32, Bool, CGEvent?) =
      switch resolveScroll(
        notch,
        isOptionHeld: originalFlags.contains(.maskAlternate),
        isTerminalFrontmost: isTerminalFrontmost(),
        options: options
      ) {
      case .vertical(let lines, let stripsOption):
        (0, lines, stripsOption, strippedEvents?.vertical)
      case .horizontal(let lines, let stripsOption):
        (lines, 0, stripsOption, strippedEvents?.horizontal)
      }

    guard stripsOption else {
      applyReplacement(to: event, linesX: linesX, linesY: linesY)
      return event
    }

    // Sandwich the stripped replacement with flagsChanged so the target sees Option release
    // before the notch and restore afterward. On synthesis failure, drop the notch rather than
    // pass through an Option-bearing event that terminals interpret as alt-scroll.
    let flags = originalFlags.subtracting(Self.allOptionFlags)
    let optionKey: CGKeyCode =
      originalFlags.contains(Self.rightOptionFlag) ? Self.rightOptionKey : Self.leftOptionKey
    guard let strippedEvents, let strippedReplacement else { return nil }

    strippedReplacement.location = event.location
    strippedReplacement.flags = flags
    strippedReplacement.timestamp = event.timestamp
    applyReplacement(to: strippedReplacement, linesX: linesX, linesY: linesY)
    strippedEvents.optionReleased.flags = flags
    strippedEvents.optionReleased.timestamp = event.timestamp
    strippedEvents.optionReleased.setIntegerValueField(
      .keyboardEventKeycode,
      value: Int64(optionKey)
    )
    strippedEvents.optionRestored.flags = originalFlags
    strippedEvents.optionRestored.timestamp = event.timestamp
    strippedEvents.optionRestored.setIntegerValueField(
      .keyboardEventKeycode,
      value: Int64(optionKey)
    )
    strippedEvents.optionReleased.tapPostEvent(proxy)
    strippedReplacement.tapPostEvent(proxy)
    strippedEvents.optionRestored.tapPostEvent(proxy)
    return nil
  }

  // Trackpad and Magic Mouse scrolling is continuous or phased; wheel notches are neither.
  private static func isDiscreteWheelEvent(_ event: CGEvent) -> Bool {
    if event.getIntegerValueField(.scrollWheelEventIsContinuous) != 0 { return false }
    if event.getIntegerValueField(.scrollWheelEventScrollPhase) != 0 { return false }
    if event.getIntegerValueField(.scrollWheelEventMomentumPhase) != 0 { return false }
    let subtype = CGEventMouseSubtype(
      rawValue: UInt32(event.getIntegerValueField(.mouseEventSubtype)))
    if subtype != .defaultType { return false }
    return event.getIntegerValueField(.tabletEventDeviceID) == 0
  }

  package func makeReplacement(location: CGPoint, flags: CGEventFlags, linesX: Int32, linesY: Int32)
    -> CGEvent?
  {
    guard
      let replacement = CGEvent(
        scrollWheelEvent2Source: source,
        units: .line,
        wheelCount: linesX == 0 ? 1 : 2,
        wheel1: linesY,
        wheel2: linesX,
        wheel3: 0
      )
    else { return nil }

    replacement.location = location
    replacement.flags = flags
    applyReplacement(to: replacement, linesX: linesX, linesY: linesY)
    return replacement
  }

  package func applyReplacement(to event: CGEvent, linesX: Int32, linesY: Int32) {
    event.setIntegerValueField(.scrollWheelEventDeltaAxis1, value: Int64(linesY))
    event.setIntegerValueField(.scrollWheelEventDeltaAxis2, value: Int64(linesX))
    event.setIntegerValueField(.scrollWheelEventDeltaAxis3, value: 0)
    event.setIntegerValueField(.scrollWheelEventFixedPtDeltaAxis1, value: Int64(linesY) * 65_536)
    event.setIntegerValueField(.scrollWheelEventFixedPtDeltaAxis2, value: Int64(linesX) * 65_536)
    event.setIntegerValueField(.scrollWheelEventFixedPtDeltaAxis3, value: 0)
    event.setIntegerValueField(
      .scrollWheelEventPointDeltaAxis1, value: Int64(linesY) * Self.pixelsPerLine)
    event.setIntegerValueField(
      .scrollWheelEventPointDeltaAxis2, value: Int64(linesX) * Self.pixelsPerLine)
    event.setIntegerValueField(.scrollWheelEventPointDeltaAxis3, value: 0)
    event.setIntegerValueField(.scrollWheelEventScrollCount, value: 1)
    event.setIntegerValueField(.scrollWheelEventIsContinuous, value: 0)
    event.setIntegerValueField(.scrollWheelEventScrollPhase, value: 0)
    event.setIntegerValueField(.scrollWheelEventMomentumPhase, value: 0)
  }
}
