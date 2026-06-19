import ApplicationServices
import Testing

@testable import ProboCore

@Suite("Scroll event synthesizer")
struct ScrollEventSynthesizerTests {
  @Test("replacement scroll lines emit tagged discrete scroll events")
  func replacementScrollLines() throws {
    let location = CGPoint(x: 12, y: 34)
    let flags: CGEventFlags = [.maskShift]
    let cases: [(linesX: Int32, linesY: Int32, axis1: Int64, axis2: Int64, note: String)] = [
      (linesX: 0, linesY: -2, axis1: -2, axis2: 0, note: "vertical"),
      (linesX: 3, linesY: 0, axis1: 0, axis2: 3, note: "horizontal"),
    ]

    for replacementCase in cases {
      let event = try replacementEvent(
        location: location,
        flags: flags,
        linesX: replacementCase.linesX,
        linesY: replacementCase.linesY
      )

      #expect(event.getIntegerValueField(.scrollWheelEventDeltaAxis1) == replacementCase.axis1)
      #expect(event.getIntegerValueField(.scrollWheelEventDeltaAxis2) == replacementCase.axis2)
      #expect(event.getIntegerValueField(.scrollWheelEventScrollCount) == 1)
      #expect(event.getIntegerValueField(.eventSourceUserData) == ScrollEventSynthesizer.marker)
      #expect(event.location == location)
      #expect(event.flags.contains(.maskShift))
    }
  }

  @Test("applying replacement lines rewrites every wheel field")
  func applyingReplacementLines() throws {
    let location = CGPoint(x: 21, y: 43)
    let event = try inputScrollEvent(location: location)
    event.flags = [.maskShift]
    event.setIntegerValueField(.eventSourceUserData, value: 123)

    ScrollEventSynthesizer().applyReplacement(to: event, linesX: 3, linesY: -2)

    let expectedFields: [(CGEventField, Int64)] = [
      (.scrollWheelEventDeltaAxis1, -2),
      (.scrollWheelEventDeltaAxis2, 3),
      (.scrollWheelEventDeltaAxis3, 0),
      (.scrollWheelEventFixedPtDeltaAxis1, -2 * 65_536),
      (.scrollWheelEventFixedPtDeltaAxis2, 3 * 65_536),
      (.scrollWheelEventFixedPtDeltaAxis3, 0),
      (.scrollWheelEventPointDeltaAxis1, -2 * 16),
      (.scrollWheelEventPointDeltaAxis2, 3 * 16),
      (.scrollWheelEventPointDeltaAxis3, 0),
      (.scrollWheelEventScrollCount, 1),
      (.scrollWheelEventIsContinuous, 0),
      (.scrollWheelEventScrollPhase, 0),
      (.scrollWheelEventMomentumPhase, 0),
    ]
    for (field, expected) in expectedFields {
      #expect(event.getIntegerValueField(field) == expected)
    }
    #expect(event.getIntegerValueField(.eventSourceUserData) == 123)
    #expect(event.location == location)
    #expect(event.flags.contains(.maskShift))
  }

  @Test("modifier restoration emits a tagged flags-changed event")
  func modifierRestoration() throws {
    let event = try flagsChangedEvent(flags: [.maskCommand], keyCode: 58)

    #expect(event.type == .flagsChanged)
    #expect(event.flags.contains(.maskCommand))
    #expect(event.getIntegerValueField(.keyboardEventKeycode) == 58)
    #expect(event.getIntegerValueField(.eventSourceUserData) == ScrollEventSynthesizer.marker)
  }
}

private func replacementEvent(
  location: CGPoint = .zero,
  flags: CGEventFlags = [],
  linesX: Int32,
  linesY: Int32
) throws -> CGEvent {
  try #require(
    ScrollEventSynthesizer().makeReplacement(
      location: location, flags: flags, linesX: linesX, linesY: linesY
    )
  )
}

private func flagsChangedEvent(flags: CGEventFlags, keyCode: CGKeyCode) throws -> CGEvent {
  try #require(ScrollEventSynthesizer().makeFlagsChanged(flags: flags, keyCode: keyCode))
}

private func inputScrollEvent(location: CGPoint) throws -> CGEvent {
  let source = CGEventSource(stateID: .hidSystemState)
  source?.pixelsPerLine = 16.0
  let event = try #require(
    CGEvent(
      scrollWheelEvent2Source: source,
      units: .line,
      wheelCount: 1,
      wheel1: 42,
      wheel2: 0,
      wheel3: 0
    )
  )
  event.location = location
  return event
}
