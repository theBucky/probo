import ApplicationServices

let scrollEventSynthesizerTests: [TestCase] = [
  TestCase(
    behavior:
      "given replacement scroll lines when synthesizing then it emits tagged discrete scroll events"
  ) {
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

      try expectEqual(
        event.getIntegerValueField(.scrollWheelEventDeltaAxis1),
        replacementCase.axis1,
        "\(replacementCase.note) replacement should emit axis1 lines"
      )
      try expectEqual(
        event.getIntegerValueField(.scrollWheelEventDeltaAxis2),
        replacementCase.axis2,
        "\(replacementCase.note) replacement should emit axis2 lines"
      )
      try expectEqual(
        event.getIntegerValueField(.scrollWheelEventScrollCount),
        1,
        "\(replacementCase.note) replacement should look like one discrete notch"
      )
      try expectEqual(
        event.getIntegerValueField(.eventSourceUserData),
        ScrollEventSynthesizer.marker,
        "\(replacementCase.note) replacement should carry the synth marker"
      )
      try expectEqual(event.location, location, "\(replacementCase.note) should preserve location")
      try expect(event.flags.contains(.maskShift), "\(replacementCase.note) should preserve flags")
    }
  },

  TestCase(
    behavior:
      "given an existing scroll event when applying replacement lines then it rewrites every wheel field"
  ) {
    let location = CGPoint(x: 21, y: 43)
    let event = try inputScrollEvent(location: location)
    event.flags = [.maskShift]
    event.setIntegerValueField(.eventSourceUserData, value: 123)

    ScrollEventSynthesizer().applyReplacement(to: event, linesX: 3, linesY: -2)

    let expectedFields: [(String, CGEventField, Int64)] = [
      ("delta axis 1", .scrollWheelEventDeltaAxis1, -2),
      ("delta axis 2", .scrollWheelEventDeltaAxis2, 3),
      ("delta axis 3", .scrollWheelEventDeltaAxis3, 0),
      ("fixed axis 1", .scrollWheelEventFixedPtDeltaAxis1, -2 * 65_536),
      ("fixed axis 2", .scrollWheelEventFixedPtDeltaAxis2, 3 * 65_536),
      ("fixed axis 3", .scrollWheelEventFixedPtDeltaAxis3, 0),
      ("point axis 1", .scrollWheelEventPointDeltaAxis1, -2 * 16),
      ("point axis 2", .scrollWheelEventPointDeltaAxis2, 3 * 16),
      ("point axis 3", .scrollWheelEventPointDeltaAxis3, 0),
      ("scroll count", .scrollWheelEventScrollCount, 1),
      ("continuous", .scrollWheelEventIsContinuous, 0),
      ("phase", .scrollWheelEventScrollPhase, 0),
      ("momentum", .scrollWheelEventMomentumPhase, 0),
    ]
    for (fieldName, field, expected) in expectedFields {
      try expectEqual(
        event.getIntegerValueField(field),
        expected,
        "applied replacement should rewrite \(fieldName)"
      )
    }
    try expectEqual(
      event.getIntegerValueField(.eventSourceUserData),
      123,
      "applied replacement should preserve event source user data"
    )
    try expectEqual(event.location, location, "applied replacement should preserve location")
    try expect(
      event.flags.contains(.maskShift), "applied replacement should leave flags untouched")
  },

  TestCase(
    behavior:
      "given modifier restoration when synthesizing then it emits a tagged flags-changed event"
  ) {
    let event = try flagsChangedEvent(flags: [.maskCommand], keyCode: 58)

    try expectEqual(event.type, .flagsChanged, "modifier event should be flagsChanged")
    try expect(event.flags.contains(.maskCommand), "modifier event should preserve flags")
    try expectEqual(
      event.getIntegerValueField(.keyboardEventKeycode),
      58,
      "modifier event should preserve the key code"
    )
    try expectEqual(
      event.getIntegerValueField(.eventSourceUserData),
      ScrollEventSynthesizer.marker,
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
  try expectNotNil(
    ScrollEventSynthesizer().makeReplacement(
      location: location, flags: flags, linesX: linesX, linesY: linesY
    ),
    "replacement scroll should be created"
  )
}

private func flagsChangedEvent(flags: CGEventFlags, keyCode: CGKeyCode) throws -> CGEvent {
  try expectNotNil(
    ScrollEventSynthesizer().makeFlagsChanged(flags: flags, keyCode: keyCode),
    "flags-changed event should be created"
  )
}

private func inputScrollEvent(location: CGPoint) throws -> CGEvent {
  let source = CGEventSource(stateID: .hidSystemState)
  source?.pixelsPerLine = 16.0
  let event = try expectNotNil(
    CGEvent(
      scrollWheelEvent2Source: source,
      units: .line,
      wheelCount: 1,
      wheel1: 42,
      wheel2: 0,
      wheel3: 0
    ),
    "input scroll should be created"
  )
  event.location = location
  return event
}
