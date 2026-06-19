import Testing

@testable import ProboCore

@Suite("Scroll rewrite core")
struct ScrollRewriteCoreTests {
  @Test("discrete wheel notches emit configured fixed line steps")
  func discreteWheelNotches() throws {
    try expectRewrite(verticalDelta: 1, linesX: 0, linesY: 2, "slow vertical notch")
    try expectRewrite(
      verticalDelta: -42,
      linesX: 0,
      linesY: -2,
      "large source delta still maps to one slow step"
    )
    try expectRewrite(
      horizontalDelta: -9,
      intensity: .medium,
      linesX: -3,
      linesY: 0,
      "medium horizontal notch"
    )
    try expectRewrite(
      horizontalDelta: Int32.min,
      intensity: .medium,
      linesX: -3,
      linesY: 0,
      "minimum source delta still maps to one medium step"
    )
  }

  @Test("precision mode emits one line regardless of intensity")
  func precisionMode() throws {
    try expectRewrite(
      verticalDelta: -1,
      intensity: .slow,
      isPrecision: true,
      linesX: 0,
      linesY: -1,
      "precision mode ignores slow intensity"
    )
    try expectRewrite(
      verticalDelta: -1,
      intensity: .medium,
      isPrecision: true,
      linesX: 0,
      linesY: -1,
      "precision mode ignores medium intensity"
    )
  }

  @Test("disabled trackpad-style scrolling reverses line direction")
  func disabledTrackpadStyleScrolling() throws {
    try expectRewrite(
      verticalDelta: 1,
      isTrackpadStyleScrollingEnabled: false,
      linesX: 0,
      linesY: -2,
      "vertical direction"
    )
    try expectRewrite(
      horizontalDelta: -9,
      intensity: .medium,
      isTrackpadStyleScrollingEnabled: false,
      linesX: 3,
      linesY: 0,
      "horizontal direction"
    )
  }

  @Test("option precision outside terminals requires setting and held option")
  func optionPrecisionOutsideTerminals() {
    expectDecision(
      decidePrecision(isOptionHeld: true, isOptionPrecisionEnabled: true),
      isPrecision: true,
      stripOption: true,
      "Option held with the setting enabled emits precision and strips Option"
    )
    expectDecision(
      decidePrecision(isOptionHeld: true, isOptionPrecisionEnabled: false),
      isPrecision: false,
      stripOption: false,
      "Option held with the setting disabled stays in intensity mode and forwards Option"
    )
    expectDecision(
      decidePrecision(isOptionHeld: false, isOptionPrecisionEnabled: true),
      isPrecision: false,
      stripOption: false,
      "Option released keeps intensity mode and leaves flags untouched"
    )
  }

  @Test("terminal optimization defaults to one line and option escapes to intensity")
  func terminalOptimization() {
    expectDecision(
      decidePrecision(isOptionHeld: false, isTerminalOptimizationActive: true),
      isPrecision: true,
      stripOption: false,
      "no Option in a terminal yields precision and needs no flag dance"
    )
    expectDecision(
      decidePrecision(isOptionHeld: true, isTerminalOptimizationActive: true),
      isPrecision: false,
      stripOption: true,
      "Option held in a terminal escapes to the wheel step and strips Option from the synthesized event"
    )
    expectDecision(
      decidePrecision(isOptionHeld: false, isTerminalOptimizationActive: false),
      isPrecision: false,
      stripOption: false,
      "terminal optimization off falls back to normal app rules"
    )
    expectDecision(
      decidePrecision(
        isOptionHeld: true,
        isOptionPrecisionEnabled: true,
        isTerminalOptimizationActive: false
      ),
      isPrecision: true,
      stripOption: true,
      "terminal optimization off still honors the Option precision setting"
    )
  }

  @Test("non-discrete or ambiguous scrolling is dropped")
  func droppedInputs() {
    #expect(
      rewrite(verticalDelta: 1, isContinuous: true) == nil, "continuous scroll must not rewrite")
    #expect(rewrite(verticalDelta: 1, hasPhase: true) == nil, "phased scroll must not rewrite")
    #expect(
      rewrite(verticalDelta: 1, horizontalDelta: 1) == nil, "diagonal scroll must not rewrite")
    #expect(rewrite() == nil, "zero-delta scroll must not rewrite")
  }
}

private func rewrite(
  verticalDelta: Int32 = 0,
  horizontalDelta: Int32 = 0,
  intensity: ScrollIntensity = .slow,
  isContinuous: Bool = false,
  hasPhase: Bool = false,
  isPrecision: Bool = false,
  isTrackpadStyleScrollingEnabled: Bool = true
) -> (linesX: Int32, linesY: Int32)? {
  ScrollRewriteCore.rewrite(
    verticalDelta: verticalDelta,
    horizontalDelta: horizontalDelta,
    intensity: intensity,
    isContinuous: isContinuous,
    hasPhase: hasPhase,
    isPrecision: isPrecision,
    isTrackpadStyleScrollingEnabled: isTrackpadStyleScrollingEnabled
  )
}

private func expectRewrite(
  verticalDelta: Int32 = 0,
  horizontalDelta: Int32 = 0,
  intensity: ScrollIntensity = .slow,
  isPrecision: Bool = false,
  isTrackpadStyleScrollingEnabled: Bool = true,
  linesX: Int32,
  linesY: Int32,
  _ message: String
) throws {
  let output = try #require(
    rewrite(
      verticalDelta: verticalDelta,
      horizontalDelta: horizontalDelta,
      intensity: intensity,
      isPrecision: isPrecision,
      isTrackpadStyleScrollingEnabled: isTrackpadStyleScrollingEnabled
    ),
    Comment(rawValue: message)
  )
  #expect(output.linesX == linesX, Comment(rawValue: "\(message): linesX"))
  #expect(output.linesY == linesY, Comment(rawValue: "\(message): linesY"))
}

private func decidePrecision(
  isOptionHeld: Bool,
  isOptionPrecisionEnabled: Bool = false,
  isTerminalOptimizationActive: Bool = false
) -> ScrollRewriteCore.PrecisionDecision {
  ScrollRewriteCore.decidePrecision(
    isOptionHeld: isOptionHeld,
    isOptionPrecisionEnabled: isOptionPrecisionEnabled,
    isTerminalOptimizationActive: isTerminalOptimizationActive
  )
}

private func expectDecision(
  _ actual: ScrollRewriteCore.PrecisionDecision,
  isPrecision: Bool,
  stripOption: Bool,
  _ message: String
) {
  #expect(actual.isPrecision == isPrecision, Comment(rawValue: "\(message): isPrecision"))
  #expect(actual.stripOption == stripOption, Comment(rawValue: "\(message): stripOption"))
}
