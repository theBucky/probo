@preconcurrency import ApplicationServices

package struct ScrollRewriter {
  // ASCII "PROBO" tags synthesized events so the tap can skip its own output.
  package static let marker: Int64 = 0x50_524F_424F
  private static let pixelsPerLine: Int64 = 16

  private let isTerminalFrontmost: @Sendable () -> Bool
  private static let leftOptionFlag = CGEventFlags(rawValue: 0x20)
  private static let rightOptionFlag = CGEventFlags(rawValue: 0x40)
  private static let allOptionFlags: CGEventFlags = [
    .maskAlternate, leftOptionFlag, rightOptionFlag,
  ]
  private static let leftOptionKey = CGKeyCode(0x3A)
  private static let rightOptionKey = CGKeyCode(0x3D)

  private let source: CGEventSource? = {
    let source = CGEventSource(stateID: .hidSystemState)
    source?.pixelsPerLine = Double(ScrollRewriter.pixelsPerLine)
    return source
  }()

  package init(isTerminalFrontmost: @escaping @Sendable () -> Bool) {
    self.isTerminalFrontmost = isTerminalFrontmost
  }

  package func rewrite(event: CGEvent, options: TapOptions) -> CGEvent? {
    guard Self.isDiscreteWheelEvent(event) else { return event }

    let verticalDelta = Int32(
      truncatingIfNeeded: event.getIntegerValueField(.scrollWheelEventDeltaAxis1))
    let horizontalDelta = Int32(
      truncatingIfNeeded: event.getIntegerValueField(.scrollWheelEventDeltaAxis2))
    let originalFlags = event.flags

    let verdict = decideScroll(
      verticalDelta: verticalDelta,
      horizontalDelta: horizontalDelta,
      isOptionHeld: originalFlags.contains(.maskAlternate),
      isTerminalFrontmost: isTerminalFrontmost(),
      options: options
    )

    switch verdict {
    case .drop:
      return nil
    case .emit(let linesX, let linesY, false):
      applyReplacement(to: event, linesX: linesX, linesY: linesY)
      return event
    case .emit(let linesX, let linesY, true):
      // stripOption implies option was held; sandwich the stripped replacement with flagsChanged
      // so the target app sees option release before our event and restore after. The sandwich is
      // best-effort, the strip is not: on synthesis failure the notch is dropped rather than
      // passing the original Option-bearing event through, which terminals would read as
      // alt-scroll.
      let flags = originalFlags.subtracting(Self.allOptionFlags)
      let optionKey: CGKeyCode =
        originalFlags.contains(Self.rightOptionFlag)
        ? Self.rightOptionKey : Self.leftOptionKey
      guard
        let replacement = makeReplacement(
          location: event.location, flags: flags, linesX: linesX, linesY: linesY
        )
      else { return nil }

      makeFlagsChanged(flags: flags, keyCode: optionKey)?.post(tap: .cgSessionEventTap)
      replacement.post(tap: .cgSessionEventTap)
      makeFlagsChanged(flags: originalFlags, keyCode: optionKey)?.post(tap: .cgSessionEventTap)
      return nil
    }
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
    let wheelCount: UInt32 = linesX == 0 ? 1 : 2
    guard
      let replacement = CGEvent(
        scrollWheelEvent2Source: source,
        units: .line,
        wheelCount: wheelCount,
        wheel1: linesY,
        wheel2: linesX,
        wheel3: 0
      )
    else { return nil }

    replacement.location = location
    replacement.flags = flags
    applyReplacement(to: replacement, linesX: linesX, linesY: linesY)
    replacement.setIntegerValueField(.eventSourceUserData, value: Self.marker)
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

  package func makeFlagsChanged(flags: CGEventFlags, keyCode: CGKeyCode) -> CGEvent? {
    guard let event = CGEvent(source: source) else { return nil }
    event.type = .flagsChanged
    event.flags = flags
    event.setIntegerValueField(.keyboardEventKeycode, value: Int64(keyCode))
    event.setIntegerValueField(.eventSourceUserData, value: Self.marker)
    return event
  }
}
