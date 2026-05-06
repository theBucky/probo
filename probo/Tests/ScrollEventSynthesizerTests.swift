import ApplicationServices

private let synthMarker: Int64 = 0x50_524F_424F

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
        synthMarker,
        "\(replacementCase.note) replacement should carry the synth marker"
      )
      try expectEqual(event.location, location, "\(replacementCase.note) should preserve location")
      try expect(event.flags.contains(.maskShift), "\(replacementCase.note) should preserve flags")
    }
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
