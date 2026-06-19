import ApplicationServices

package struct ScrollEventSynthesizer {
  // ASCII "PROBO" — tags synthesized events so the tap can skip its own output.
  package static let marker: Int64 = 0x50_524F_424F
  private static let pixelsPerLine: Int64 = 16

  private let source: CGEventSource? = {
    let source = CGEventSource(stateID: .hidSystemState)
    source?.pixelsPerLine = Double(Self.pixelsPerLine)
    return source
  }()

  package init() {}

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
    else {
      return nil
    }

    replacement.location = location
    replacement.flags = flags
    applyReplacement(to: replacement, linesX: linesX, linesY: linesY)
    replacement.setIntegerValueField(.eventSourceUserData, value: Self.marker)
    return replacement
  }

  // Overwrites only the wheel fields; location, flags, and source user data stay untouched
  // so the in-place rewrite path keeps the original event's identity for free.
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
