import ApplicationServices

private let synthMarker: Int64 = 0x50_524F_424F

let scrollEventSynthesizerTests: [TestCase] = [
  TestCase(
    behavior:
      "given replacement scroll lines when synthesizing then it preserves location and flags"
  ) {
    let event = try replacementEvent(
      location: CGPoint(x: 12, y: 34),
      flags: [.maskShift],
      linesX: 0,
      linesY: -2
    )

    try expectEqual(event.location, CGPoint(x: 12, y: 34), "replacement should preserve location")
    try expect(event.flags.contains(.maskShift), "replacement should preserve flags")
  },

  TestCase(
    behavior: "given vertical replacement lines when synthesizing then it emits axis1 deltas only"
  ) {
    let event = try replacementEvent(linesX: 0, linesY: -2)

    try expectEqual(
      event.getIntegerValueField(.scrollWheelEventDeltaAxis1),
      -2,
      "vertical replacement should emit axis1 lines"
    )
    try expectEqual(
      event.getIntegerValueField(.scrollWheelEventDeltaAxis2),
      0,
      "vertical replacement should leave axis2 empty"
    )
  },

  TestCase(
    behavior: "given horizontal replacement lines when synthesizing then it emits axis2 deltas only"
  ) {
    let event = try replacementEvent(linesX: 3, linesY: 0)

    try expectEqual(
      event.getIntegerValueField(.scrollWheelEventDeltaAxis1),
      0,
      "horizontal replacement should leave axis1 empty"
    )
    try expectEqual(
      event.getIntegerValueField(.scrollWheelEventDeltaAxis2),
      3,
      "horizontal replacement should emit axis2 lines"
    )
  },

  TestCase(
    behavior: "given replacement scroll lines when synthesizing then it marks one discrete notch"
  ) {
    let event = try replacementEvent(linesX: 0, linesY: -2)

    try expectEqual(
      event.getIntegerValueField(.scrollWheelEventScrollCount),
      1,
      "replacement should look like one discrete notch"
    )
  },

  TestCase(
    behavior:
      "given replacement scroll lines when synthesizing then it tags the event as synthesized"
  ) {
    let event = try replacementEvent(linesX: 0, linesY: -2)

    try expectEqual(
      event.getIntegerValueField(.eventSourceUserData),
      synthMarker,
      "replacement should carry the synth marker"
    )
  },

  TestCase(
    behavior: "given modifier restoration when synthesizing then it emits a flags-changed event"
  ) {
    let event = try flagsChangedEvent(flags: [.maskCommand], keyCode: 58)

    try expectEqual(event.type, .flagsChanged, "modifier event should be flagsChanged")
    try expect(event.flags.contains(.maskCommand), "modifier event should preserve flags")
    try expectEqual(
      event.getIntegerValueField(.keyboardEventKeycode),
      58,
      "modifier event should preserve the key code"
    )
  },

  TestCase(
    behavior: "given modifier restoration when synthesizing then it tags the event as synthesized"
  ) {
    let event = try flagsChangedEvent(flags: [.maskCommand], keyCode: 58)

    try expectEqual(
      event.getIntegerValueField(.eventSourceUserData),
      synthMarker,
      "modifier event should carry the synth marker"
    )
  },
]

private func replacementEvent(
  location: CGPoint = .zero,
  flags: CGEventFlags = [],
  linesX: Int32,
  linesY: Int32
) throws -> CGEvent {
  let synthesizer = ScrollEventSynthesizer(marker: synthMarker)
  return try expectNotNil(
    synthesizer.makeReplacement(location: location, flags: flags, linesX: linesX, linesY: linesY),
    "replacement scroll should be created"
  )
}

private func flagsChangedEvent(flags: CGEventFlags, keyCode: CGKeyCode) throws -> CGEvent {
  let synthesizer = ScrollEventSynthesizer(marker: synthMarker)
  return try expectNotNil(
    synthesizer.makeFlagsChanged(flags: flags, keyCode: keyCode),
    "flags-changed event should be created"
  )
}
