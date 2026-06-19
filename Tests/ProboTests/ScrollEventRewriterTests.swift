import ApplicationServices
import Testing

@testable import ProboCore

@Suite("Scroll event rewriter")
struct ScrollEventRewriterTests {
  @Test("valid wheel event rewrites in place")
  func validWheelEvent() throws {
    let event = try scrollEvent(verticalDelta: 1)
    let output = ScrollEventRewriter(isTerminalFrontmost: { false })
      .rewrite(event: event, options: EventTapOptions(configuration: AppConfiguration()))

    #expect(output != nil)
    #expect(event.getIntegerValueField(.scrollWheelEventDeltaAxis1) == -2)
    #expect(event.getIntegerValueField(.scrollWheelEventDeltaAxis2) == 0)
  }

  @Test("non-discrete or ambiguous wheel events are dropped")
  func droppedInputs() throws {
    let rewriter = ScrollEventRewriter(isTerminalFrontmost: { false })
    let options = EventTapOptions(configuration: AppConfiguration())

    let continuous = try scrollEvent(verticalDelta: 1)
    continuous.setIntegerValueField(.scrollWheelEventIsContinuous, value: 1)

    let phased = try scrollEvent(verticalDelta: 1)
    phased.setIntegerValueField(.scrollWheelEventScrollPhase, value: 1)

    let momentum = try scrollEvent(verticalDelta: 1)
    momentum.setIntegerValueField(.scrollWheelEventMomentumPhase, value: 1)

    let diagonal = try scrollEvent(verticalDelta: 1, horizontalDelta: 1)
    let zero = try scrollEvent()

    for event in [continuous, phased, momentum, diagonal, zero] {
      #expect(rewriter.rewrite(event: event, options: options) == nil)
    }
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
