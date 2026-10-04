import ApplicationServices
import Testing

@testable import ProboCore

@Suite("Scroll rewriter")
struct ScrollRewriterTests {
  private let rewriter = ScrollRewriter()
  private let configuration = InputConfiguration()

  @Test("wheel notches rewrite in place to configured lines on their own axis")
  func inPlaceRewrite() throws {
    let vertical = try scrollEvent(verticalDelta: 3)
    let horizontal = try scrollEvent(horizontalDelta: -1)
    let inTerminal = try scrollEvent(verticalDelta: 1)

    #expect(
      rewriter.rewrite(vertical, configuration: configuration, isTerminalFrontmost: false)
        .isDeliver)
    #expect(vertical.getIntegerValueField(.scrollWheelEventDeltaAxis1) == -2)
    #expect(vertical.getIntegerValueField(.scrollWheelEventDeltaAxis2) == 0)
    #expect(vertical.getIntegerValueField(.scrollWheelEventFixedPtDeltaAxis1) == -2 * 65_536)
    #expect(vertical.getIntegerValueField(.scrollWheelEventPointDeltaAxis1) == -32)

    #expect(
      rewriter.rewrite(horizontal, configuration: configuration, isTerminalFrontmost: false)
        .isDeliver)
    #expect(horizontal.getIntegerValueField(.scrollWheelEventDeltaAxis1) == 0)
    #expect(horizontal.getIntegerValueField(.scrollWheelEventDeltaAxis2) == 2)
    #expect(horizontal.getIntegerValueField(.scrollWheelEventPointDeltaAxis2) == 32)

    #expect(
      rewriter.rewrite(inTerminal, configuration: configuration, isTerminalFrontmost: true)
        .isDeliver)
    #expect(inTerminal.getIntegerValueField(.scrollWheelEventDeltaAxis1) == -1)
  }

  @Test("continuous and phased events pass through untouched")
  func passthroughInputs() throws {
    let continuous = try scrollEvent(verticalDelta: 1)
    continuous.setIntegerValueField(.scrollWheelEventIsContinuous, value: 1)

    let phased = try scrollEvent(verticalDelta: 1)
    phased.setIntegerValueField(.scrollWheelEventScrollPhase, value: 1)

    let momentum = try scrollEvent(verticalDelta: 1)
    momentum.setIntegerValueField(.scrollWheelEventMomentumPhase, value: 1)

    for event in [continuous, phased, momentum] {
      let rewrite = rewriter.rewrite(
        event, configuration: configuration, isTerminalFrontmost: false)
      #expect(rewrite.isDeliver)
      #expect(event.getIntegerValueField(.scrollWheelEventDeltaAxis1) == 1)
    }
  }

  @Test("ambiguous wheel events are dropped")
  func droppedInputs() throws {
    let diagonal = try scrollEvent(verticalDelta: 1, horizontalDelta: 1)
    let zero = try scrollEvent()

    for event in [diagonal, zero] {
      let rewrite = rewriter.rewrite(
        event, configuration: configuration, isTerminalFrontmost: false)
      #expect(rewrite.isDrop)
    }
  }

  @Test("option precision strips Option around a one-line notch")
  func optionStrip() throws {
    let event = try scrollEvent(verticalDelta: 1)
    event.flags = [.maskAlternate, .maskShift, CGEventFlags(rawValue: 0x40)]
    event.timestamp = 1234
    event.location = CGPoint(x: 40, y: 60)
    let configuration = InputConfiguration(isOptionPrecisionEnabled: true)

    let rewrite = rewriter.rewrite(event, configuration: configuration, isTerminalFrontmost: false)

    let stripped = try #require(rewrite.stripped)
    #expect(stripped.notch.getIntegerValueField(.scrollWheelEventDeltaAxis1) == -1)
    #expect(stripped.notch.flags == [.maskShift])
    #expect(stripped.notch.timestamp == 1234)
    #expect(stripped.notch.location == CGPoint(x: 40, y: 60))
    #expect(stripped.optionReleased.type == .flagsChanged)
    #expect(stripped.optionReleased.flags == [.maskShift])
    #expect(stripped.optionReleased.getIntegerValueField(.keyboardEventKeycode) == 0x3D)
    #expect(stripped.optionRestored.type == .flagsChanged)
    #expect(stripped.optionRestored.flags == event.flags)
    #expect(stripped.optionRestored.timestamp == 1234)
    #expect(event.getIntegerValueField(.scrollWheelEventDeltaAxis1) == 1)
  }

  @Test("horizontal strip releases left Option by default and keeps the axis")
  func horizontalOptionStrip() throws {
    let event = try scrollEvent(horizontalDelta: 1)
    event.flags = [.maskAlternate]
    let configuration = InputConfiguration(isOptionPrecisionEnabled: true)

    let rewrite = rewriter.rewrite(event, configuration: configuration, isTerminalFrontmost: false)

    let stripped = try #require(rewrite.stripped)
    #expect(stripped.notch.getIntegerValueField(.scrollWheelEventDeltaAxis1) == 0)
    #expect(stripped.notch.getIntegerValueField(.scrollWheelEventDeltaAxis2) == -1)
    #expect(stripped.notch.flags.contains(.maskAlternate) == false)
    #expect(stripped.optionReleased.getIntegerValueField(.keyboardEventKeycode) == 0x3A)
    #expect(stripped.optionRestored.flags == [.maskAlternate])
  }
}

extension ScrollRewrite {
  fileprivate var isDeliver: Bool {
    if case .deliver = self { true } else { false }
  }

  fileprivate var isDrop: Bool {
    if case .drop = self { true } else { false }
  }

  fileprivate var stripped: StrippedNotch? {
    if case .post(let stripped) = self { stripped } else { nil }
  }
}

private func scrollEvent(verticalDelta: Int32 = 0, horizontalDelta: Int32 = 0) throws -> CGEvent {
  let source = CGEventSource(stateID: .hidSystemState)
  source?.pixelsPerLine = 16.0
  let event = try #require(
    CGEvent(
      scrollWheelEvent2Source: source,
      units: .line,
      wheelCount: horizontalDelta == 0 ? 1 : 2,
      wheel1: verticalDelta,
      wheel2: horizontalDelta,
      wheel3: 0
    )
  )
  event.setIntegerValueField(.scrollWheelEventScrollCount, value: 1)
  return event
}
