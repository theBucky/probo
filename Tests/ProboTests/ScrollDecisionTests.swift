import Testing

@testable import ProboCore

@Suite("Scroll decision")
struct ScrollDecisionTests {
  @Test("wheel notches emit configured line steps")
  func wheelNotches() {
    expect(
      verticalDelta: 1,
      options: options(wheelStep: .slow, natural: true),
      verdict: .emit(linesX: 0, linesY: 2, stripsOption: false)
    )
    expect(
      verticalDelta: -42,
      options: options(wheelStep: .slow, natural: true),
      verdict: .emit(linesX: 0, linesY: -2, stripsOption: false)
    )
    expect(
      horizontalDelta: -9,
      options: options(wheelStep: .medium, natural: true),
      verdict: .emit(linesX: -3, linesY: 0, stripsOption: false)
    )
  }

  @Test("precision and terminal rules choose one-line or configured step")
  func precisionRules() {
    expect(
      verticalDelta: -1,
      isOptionHeld: true,
      options: options(wheelStep: .medium, optionPrecision: true, natural: true),
      verdict: .emit(linesX: 0, linesY: -1, stripsOption: true)
    )
    expect(
      verticalDelta: -1,
      isOptionHeld: true,
      options: options(wheelStep: .medium, natural: true),
      verdict: .emit(linesX: 0, linesY: -3, stripsOption: false)
    )
    expect(
      verticalDelta: -1,
      isTerminalFrontmost: true,
      options: options(wheelStep: .medium, terminalOptimization: true, natural: true),
      verdict: .emit(linesX: 0, linesY: -1, stripsOption: false)
    )
    expect(
      verticalDelta: -1,
      isOptionHeld: true,
      isTerminalFrontmost: true,
      options: options(wheelStep: .medium, terminalOptimization: true, natural: true),
      verdict: .emit(linesX: 0, linesY: -3, stripsOption: true)
    )
    expect(
      verticalDelta: -1,
      isTerminalFrontmost: true,
      options: options(wheelStep: .medium, natural: true),
      verdict: .emit(linesX: 0, linesY: -3, stripsOption: false)
    )
  }

  @Test("disabled natural direction reverses output")
  func direction() {
    expect(
      verticalDelta: 1,
      options: options(wheelStep: .slow, natural: false),
      verdict: .emit(linesX: 0, linesY: -2, stripsOption: false)
    )
  }

  @Test("ambiguous wheel scrolling is dropped")
  func droppedInputs() {
    expect(verticalDelta: 1, horizontalDelta: 1, verdict: .drop)
    expect(verdict: .drop)
  }
}

private func expect(
  verticalDelta: Int32 = 0,
  horizontalDelta: Int32 = 0,
  isOptionHeld: Bool = false,
  isTerminalFrontmost: Bool = false,
  options: TapOptions = options(),
  verdict: ScrollVerdict
) {
  #expect(
    decideScroll(
      verticalDelta: verticalDelta,
      horizontalDelta: horizontalDelta,
      isOptionHeld: isOptionHeld,
      isTerminalFrontmost: isTerminalFrontmost,
      options: options
    ) == verdict
  )
}

private func options(
  wheelStep: WheelStep = .slow,
  optionPrecision: Bool = false,
  terminalOptimization: Bool = false,
  natural: Bool = true
) -> TapOptions {
  TapOptions(
    configuration: AppConfiguration(
      wheelStep: wheelStep,
      isOptionPrecisionEnabled: optionPrecision,
      isTerminalOptimizationEnabled: terminalOptimization,
      isTrackpadStyleScrollingEnabled: natural
    )
  )
}
