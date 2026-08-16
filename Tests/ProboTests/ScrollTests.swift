import Testing

@testable import ProboCore

@Suite("Scroll")
struct ScrollTests {
  @Test("raw deltas parse only one-axis wheel notches")
  func notchParsing() {
    #expect(WheelNotch(verticalDelta: 42, horizontalDelta: 0) == .vertical(.positive))
    #expect(WheelNotch(verticalDelta: 0, horizontalDelta: -9) == .horizontal(.negative))
    #expect(WheelNotch(verticalDelta: 1, horizontalDelta: 1) == nil)
    #expect(WheelNotch(verticalDelta: 0, horizontalDelta: 0) == nil)
  }

  @Test("wheel notches emit configured line steps")
  func wheelNotches() {
    expect(
      .vertical(.positive),
      options: options(wheelStep: .slow, natural: true),
      output: .vertical(lines: 2, stripsOption: false)
    )
    expect(
      .vertical(.negative),
      options: options(wheelStep: .slow, natural: true),
      output: .vertical(lines: -2, stripsOption: false)
    )
    expect(
      .horizontal(.negative),
      options: options(wheelStep: .medium, natural: true),
      output: .horizontal(lines: -3, stripsOption: false)
    )
  }

  @Test("precision and terminal rules choose one-line or configured step")
  func precisionRules() {
    expect(
      .vertical(.negative),
      isOptionHeld: true,
      options: options(wheelStep: .medium, optionPrecision: true, natural: true),
      output: .vertical(lines: -1, stripsOption: true)
    )
    expect(
      .vertical(.negative),
      isOptionHeld: true,
      options: options(wheelStep: .medium, natural: true),
      output: .vertical(lines: -3, stripsOption: false)
    )
    expect(
      .vertical(.negative),
      isTerminalFrontmost: true,
      options: options(wheelStep: .medium, terminalOptimization: true, natural: true),
      output: .vertical(lines: -1, stripsOption: false)
    )
    expect(
      .vertical(.negative),
      isOptionHeld: true,
      isTerminalFrontmost: true,
      options: options(wheelStep: .medium, terminalOptimization: true, natural: true),
      output: .vertical(lines: -3, stripsOption: true)
    )
    expect(
      .vertical(.negative),
      isTerminalFrontmost: true,
      options: options(wheelStep: .medium, natural: true),
      output: .vertical(lines: -3, stripsOption: false)
    )
  }

  @Test("disabled natural direction reverses output")
  func direction() {
    expect(
      .vertical(.positive),
      options: options(wheelStep: .slow, natural: false),
      output: .vertical(lines: -2, stripsOption: false)
    )
  }
}

private func expect(
  _ notch: WheelNotch,
  isOptionHeld: Bool = false,
  isTerminalFrontmost: Bool = false,
  options: ScrollOptions = options(),
  output: ScrollOutput
) {
  #expect(
    resolveScroll(
      notch,
      isOptionHeld: isOptionHeld,
      isTerminalFrontmost: isTerminalFrontmost,
      options: options
    ) == output
  )
}

private func options(
  wheelStep: WheelStep = .slow,
  optionPrecision: Bool = false,
  terminalOptimization: Bool = false,
  natural: Bool = true
) -> ScrollOptions {
  ScrollOptions(
    configuration: InputConfiguration(
      wheelStep: wheelStep,
      isOptionPrecisionEnabled: optionPrecision,
      isTerminalOptimizationEnabled: terminalOptimization,
      isTrackpadStyleScrollingEnabled: natural
    )
  )
}
