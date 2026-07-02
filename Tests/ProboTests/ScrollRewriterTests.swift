import ApplicationServices
import Testing

@testable import ProboCore

@Suite("Scroll rewriter")
struct ScrollRewriterTests {
  @Test("valid wheel event rewrites in place")
  func validWheelEvent() throws {
    let event = try scrollEvent(verticalDelta: 1)
    let output = ScrollRewriter(isTerminalFrontmost: { false })
      .rewrite(event: event, options: TapOptions(configuration: AppConfiguration()), proxy: nil)

    #expect(output != nil)
    #expect(event.getIntegerValueField(.scrollWheelEventDeltaAxis1) == -2)
    #expect(event.getIntegerValueField(.scrollWheelEventDeltaAxis2) == 0)
  }

  @Test("continuous and phased events pass through untouched")
  func passthroughInputs() throws {
    let rewriter = ScrollRewriter(isTerminalFrontmost: { false })
    let options = TapOptions(configuration: AppConfiguration())

    let continuous = try scrollEvent(verticalDelta: 1)
    continuous.setIntegerValueField(.scrollWheelEventIsContinuous, value: 1)

    let phased = try scrollEvent(verticalDelta: 1)
    phased.setIntegerValueField(.scrollWheelEventScrollPhase, value: 1)

    let momentum = try scrollEvent(verticalDelta: 1)
    momentum.setIntegerValueField(.scrollWheelEventMomentumPhase, value: 1)

    for event in [continuous, phased, momentum] {
      #expect(rewriter.rewrite(event: event, options: options, proxy: nil) === event)
      #expect(event.getIntegerValueField(.scrollWheelEventDeltaAxis1) == 1)
    }
  }

  @Test("ambiguous wheel events are dropped")
  func droppedInputs() throws {
    let rewriter = ScrollRewriter(isTerminalFrontmost: { false })
    let options = TapOptions(configuration: AppConfiguration())

    let diagonal = try scrollEvent(verticalDelta: 1, horizontalDelta: 1)
    let zero = try scrollEvent()

    for event in [diagonal, zero] {
      #expect(rewriter.rewrite(event: event, options: options, proxy: nil) == nil)
    }
  }

  @Test("synthesized replacement and flags events carry the requested fields")
  func synthesizedEvents() throws {
    let rewriter = ScrollRewriter(isTerminalFrontmost: { false })
    let replacement = try #require(
      rewriter.makeReplacement(
        location: CGPoint(x: 12, y: 34), flags: [.maskShift], linesX: 3, linesY: 0)
    )
    let flags = try #require(rewriter.makeFlagsChanged(flags: [.maskCommand], keyCode: 58))

    #expect(replacement.getIntegerValueField(.scrollWheelEventDeltaAxis2) == 3)
    #expect(replacement.location == CGPoint(x: 12, y: 34))
    #expect(replacement.flags.contains(.maskShift))
    #expect(flags.type == .flagsChanged)
    #expect(flags.getIntegerValueField(.keyboardEventKeycode) == 58)
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
