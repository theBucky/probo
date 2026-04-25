import ApplicationServices

final class ScrollEventSynthesizer {
  private let marker: Int64
  private let source: CGEventSource? = {
    let source = CGEventSource(stateID: .hidSystemState)
    source?.pixelsPerLine = 16.0
    return source
  }()

  init(marker: Int64) {
    self.marker = marker
  }

  func makeReplacement(location: CGPoint, flags: CGEventFlags, linesX: Int32, linesY: Int32)
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
    // synthesized events default ScrollCount to 0; real HID notches send 1.
    replacement.setIntegerValueField(.scrollWheelEventScrollCount, value: 1)
    replacement.setIntegerValueField(.eventSourceUserData, value: marker)
    return replacement
  }

  func makeFlagsChanged(flags: CGEventFlags, keyCode: CGKeyCode) -> CGEvent? {
    guard let event = CGEvent(source: source) else { return nil }
    event.type = .flagsChanged
    event.flags = flags
    event.setIntegerValueField(.keyboardEventKeycode, value: Int64(keyCode))
    event.setIntegerValueField(.eventSourceUserData, value: marker)
    return event
  }
}
