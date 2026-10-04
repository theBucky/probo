import ApplicationServices
import Testing

@testable import ProboCore

@Suite("Scroll rewriter")
struct ScrollRewriterTests {
  private let rewriter = ScrollRewriter()
  private let configuration = InputConfiguration()

  @Test("valid wheel event rewrites in place")
  func validWheelEvent() throws {
    let event = try scrollEvent(verticalDelta: 1)

    let rewrite = rewriter.rewrite(event, configuration: configuration, isTerminalFrontmost: false)

    #expect(rewrite.isDeliver)
    #expect(event.getIntegerValueField(.scrollWheelEventDeltaAxis1) == -2)
    #expect(event.getIntegerValueField(.scrollWheelEventDeltaAxis2) == 0)
    #expect(event.getIntegerValueField(.scrollWheelEventPointDeltaAxis1) == -32)
  }

  @Test("horizontal notch rewrites the second axis")
  func horizontalWheelEvent() throws {
    let event = try scrollEvent(horizontalDelta: -1)

    let rewrite = rewriter.rewrite(event, configuration: configuration, isTerminalFrontmost: false)

    #expect(rewrite.isDeliver)
    #expect(event.getIntegerValueField(.scrollWheelEventDeltaAxis1) == 0)
    #expect(event.getIntegerValueField(.scrollWheelEventDeltaAxis2) == 2)
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
    let configuration = InputConfiguration(isOptionPrecisionEnabled: true)

    let rewrite = rewriter.rewrite(event, configuration: configuration, isTerminalFrontmost: false)

    let stripped = try #require(rewrite.stripped)
    #expect(stripped.notch.getIntegerValueField(.scrollWheelEventDeltaAxis1) == -1)
    #expect(stripped.notch.flags == [.maskShift])
    #expect(stripped.notch.timestamp == 1234)
    #expect(stripped.optionReleased.type == .flagsChanged)
    #expect(stripped.optionReleased.flags == [.maskShift])
    #expect(stripped.optionReleased.getIntegerValueField(.keyboardEventKeycode) == 0x3D)
    #expect(stripped.optionRestored.type == .flagsChanged)
    #expect(stripped.optionRestored.flags == event.flags)
    #expect(stripped.optionRestored.timestamp == 1234)
    #expect(event.getIntegerValueField(.scrollWheelEventDeltaAxis1) == 1)
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
