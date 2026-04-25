import ApplicationServices

@_silgen_name("CGEventSetType")
private func _CGEventSetType(_ event: CGEvent, _ type: CGEventType)

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

  func postReplacement(
    location: CGPoint,
    flags: CGEventFlags,
    linesX: Int32,
    linesY: Int32,
    stepMode: ScrollStepMode
  ) -> Bool {
    if stepMode == .classic {
      guard
        let replacement = makeReplacement(
          location: location,
          flags: flags,
          linesX: linesX,
          linesY: linesY
        )
      else {
        return false
      }
      replacement.post(tap: .cgSessionEventTap)
      return true
    }

    let unitX = linesX.signum()
    let unitY = linesY.signum()
    let count = max(linesX.magnitude, linesY.magnitude)
    precondition(count > 0 && count <= 3)

    func makeUnitReplacement() -> CGEvent? {
      makeReplacement(location: location, flags: flags, linesX: unitX, linesY: unitY)
    }

    let first = makeUnitReplacement()
    let second = count > 1 ? makeUnitReplacement() : nil
    let third = count > 2 ? makeUnitReplacement() : nil

    guard
      let first,
      count == 1 || second != nil,
      count < 3 || third != nil
    else {
      return false
    }

    first.post(tap: .cgSessionEventTap)
    second?.post(tap: .cgSessionEventTap)
    third?.post(tap: .cgSessionEventTap)
    return true
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
    replacement.setIntegerValueField(.eventSourceUserData, value: marker)
    return replacement
  }

  func makeFlagsChanged(flags: CGEventFlags, keyCode: CGKeyCode) -> CGEvent? {
    guard let event = CGEvent(source: source) else { return nil }
    _CGEventSetType(event, .flagsChanged)
    event.flags = flags
    event.setIntegerValueField(.keyboardEventKeycode, value: Int64(keyCode))
    event.setIntegerValueField(.eventSourceUserData, value: marker)
    return event
  }
}
