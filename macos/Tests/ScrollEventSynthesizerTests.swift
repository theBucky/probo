import ApplicationServices
import Foundation

let scrollEventSynthesizerTests: [TestCase] = [
  TestCase(
    behavior: "given replacement scroll lines when synthesizing then it marks a line event"
  ) {
    let marker: Int64 = 0x50_524F_424F
    let synthesizer = ScrollEventSynthesizer(marker: marker)
    let event = try expectNotNil(
      synthesizer.makeReplacement(
        location: CGPoint(x: 12, y: 34),
        flags: [.maskShift],
        linesX: 0,
        linesY: -2
      ),
      "replacement scroll should be created"
    )

    try expectEqual(event.type, .scrollWheel, "replacement should be a scroll event")
    try expectEqual(event.location, CGPoint(x: 12, y: 34), "replacement should preserve location")
    try expect(event.flags.contains(.maskShift), "replacement should preserve flags")
    try expectEqual(
      event.getIntegerValueField(.scrollWheelEventDeltaAxis1),
      -2,
      "replacement should emit vertical line delta"
    )
    try expectEqual(
      event.getIntegerValueField(.scrollWheelEventDeltaAxis2),
      0,
      "replacement should keep horizontal delta empty"
    )
    try expectEqual(
      event.getIntegerValueField(.scrollWheelEventScrollCount),
      1,
      "replacement should look like one discrete HID notch"
    )
    try expectEqual(
      event.getIntegerValueField(.eventSourceUserData),
      marker,
      "replacement should carry synth marker"
    )
  },

  TestCase(
    behavior: "given horizontal replacement lines when synthesizing then it emits wheel two"
  ) {
    let marker: Int64 = 0x50_524F_424F
    let synthesizer = ScrollEventSynthesizer(marker: marker)
    let event = try expectNotNil(
      synthesizer.makeReplacement(
        location: .zero,
        flags: [],
        linesX: 3,
        linesY: 0
      ),
      "horizontal replacement should be created"
    )

    try expectEqual(
      event.getIntegerValueField(.scrollWheelEventDeltaAxis1),
      0,
      "horizontal replacement should keep vertical delta empty"
    )
    try expectEqual(
      event.getIntegerValueField(.scrollWheelEventDeltaAxis2),
      3,
      "horizontal replacement should emit horizontal line delta"
    )
  },

  TestCase(
    behavior: "given modifier restoration when synthesizing then it marks a flags-changed event"
  ) {
    let marker: Int64 = 0x50_524F_424F
    let synthesizer = ScrollEventSynthesizer(marker: marker)
    let event = try expectNotNil(
      synthesizer.makeFlagsChanged(flags: [.maskCommand], keyCode: 58),
      "flags-changed event should be created"
    )

    try expectEqual(event.type, .flagsChanged, "modifier event should be flagsChanged")
    try expect(event.flags.contains(.maskCommand), "modifier event should preserve flags")
    try expectEqual(
      event.getIntegerValueField(.keyboardEventKeycode),
      58,
      "modifier event should preserve key code"
    )
    try expectEqual(
      event.getIntegerValueField(.eventSourceUserData),
      marker,
      "modifier event should carry synth marker"
    )
  },
]
