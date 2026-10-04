import Testing

@testable import ProboCore

@Suite("Scroll policy")
struct ScrollPolicyTests {
  @Test("raw deltas parse only one-axis wheel notches")
  func notchParsing() {
    #expect(
      WheelNotch(verticalDelta: 42, horizontalDelta: 0)
        == WheelNotch(axis: .vertical, direction: .positive))
    #expect(
      WheelNotch(verticalDelta: 0, horizontalDelta: -9)
        == WheelNotch(axis: .horizontal, direction: .negative))
    #expect(WheelNotch(verticalDelta: 1, horizontalDelta: 1) == nil)
    #expect(WheelNotch(verticalDelta: 0, horizontalDelta: 0) == nil)
  }

  @Test("wheel notches emit configured line steps signed by direction and natural setting")
  func wheelNotches() {
    expect(
      .vertical, .positive,
      configuration: configuration(wheelStep: .slow, natural: true),
      step: ScrollStep(axis: .vertical, lines: 2, stripsOption: false)
    )
    expect(
      .horizontal, .negative,
      configuration: configuration(wheelStep: .medium, natural: true),
      step: ScrollStep(axis: .horizontal, lines: -3, stripsOption: false)
    )
    expect(
      .vertical, .positive,
      configuration: configuration(wheelStep: .slow, natural: false),
      step: ScrollStep(axis: .vertical, lines: -2, stripsOption: false)
    )
  }

  @Test("precision and terminal rules choose one-line or configured step")
  func precisionRules() {
    expect(
      .vertical, .negative,
      isOptionHeld: true,
      configuration: configuration(wheelStep: .medium, optionPrecision: true, natural: true),
      step: ScrollStep(axis: .vertical, lines: -1, stripsOption: true)
    )
    expect(
      .vertical, .negative,
      isOptionHeld: true,
      configuration: configuration(wheelStep: .medium, natural: true),
      step: ScrollStep(axis: .vertical, lines: -3, stripsOption: false)
    )
    expect(
      .vertical, .negative,
      isTerminalFrontmost: true,
      configuration: configuration(wheelStep: .medium, terminalOptimization: true, natural: true),
      step: ScrollStep(axis: .vertical, lines: -1, stripsOption: false)
    )
    expect(
      .vertical, .negative,
      isOptionHeld: true,
      isTerminalFrontmost: true,
      configuration: configuration(wheelStep: .medium, terminalOptimization: true, natural: true),
      step: ScrollStep(axis: .vertical, lines: -3, stripsOption: true)
    )
    expect(
      .vertical, .negative,
      isTerminalFrontmost: true,
      configuration: configuration(wheelStep: .medium, natural: true),
      step: ScrollStep(axis: .vertical, lines: -3, stripsOption: false)
    )
  }
}

private func expect(
  _ axis: ScrollAxis,
  _ direction: WheelDirection,
  isOptionHeld: Bool = false,
  isTerminalFrontmost: Bool = false,
  configuration: InputConfiguration,
  step: ScrollStep
) {
  #expect(
    configuration.scrollStep(
      for: WheelNotch(axis: axis, direction: direction),
      isOptionHeld: isOptionHeld,
      isTerminalFrontmost: isTerminalFrontmost
    ) == step
  )
}

private func configuration(
  wheelStep: WheelStep = .slow,
  optionPrecision: Bool = false,
  terminalOptimization: Bool = false,
  natural: Bool = true
) -> InputConfiguration {
  InputConfiguration(
    wheelStep: wheelStep,
    isOptionPrecisionEnabled: optionPrecision,
    isTerminalOptimizationEnabled: terminalOptimization,
    isTrackpadStyleScrollingEnabled: natural
  )
}
