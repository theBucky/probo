let scrollRewriteCoreTests: [TestCase] = [
  TestCase(
    behavior:
      "given discrete wheel notches when rewriting then it emits configured fixed line steps"
  ) {
    try expectRewrite(
      scrollInput(deltaAxis1: 1),
      ScrollRewriteOutput(linesX: 0, linesY: 2),
      "slow vertical notch"
    )
    try expectRewrite(
      scrollInput(deltaAxis1: -42),
      ScrollRewriteOutput(linesX: 0, linesY: -2),
      "large source delta still maps to one slow step"
    )
    try expectRewrite(
      scrollInput(deltaAxis2: -9, intensity: .medium),
      ScrollRewriteOutput(linesX: -3, linesY: 0),
      "medium horizontal notch"
    )
    try expectRewrite(
      scrollInput(deltaAxis2: Int32.min, intensity: .medium),
      ScrollRewriteOutput(linesX: -3, linesY: 0),
      "minimum source delta still maps to one medium step"
    )
  },

  TestCase(
    behavior: "given precision mode when rewriting then it emits one line regardless of intensity"
  ) {
    try expectRewrite(
      scrollInput(deltaAxis1: -1, intensity: .slow, isPrecision: true),
      ScrollRewriteOutput(linesX: 0, linesY: -1),
      "precision mode ignores slow intensity"
    )
    try expectRewrite(
      scrollInput(deltaAxis1: -1, intensity: .medium, isPrecision: true),
      ScrollRewriteOutput(linesX: 0, linesY: -1),
      "precision mode ignores medium intensity"
    )
  },

  TestCase(
    behavior:
      "given trackpad-style scrolling is disabled when rewriting then it reverses line direction"
  ) {
    try expectRewrite(
      scrollInput(deltaAxis1: 1, isTrackpadStyleScrollingEnabled: false),
      ScrollRewriteOutput(linesX: 0, linesY: -2),
      "vertical direction"
    )
    try expectRewrite(
      scrollInput(
        deltaAxis2: -9,
        intensity: .medium,
        isTrackpadStyleScrollingEnabled: false
      ),
      ScrollRewriteOutput(linesX: 3, linesY: 0),
      "horizontal direction"
    )
  },

  TestCase(
    behavior:
      "given precision outside terminals then Option precision must be enabled and Option held"
  ) {
    try expectDecision(
      decidePrecision(isOptionHeld: true, isOptionPrecisionEnabled: true),
      isPrecision: true,
      stripOption: true,
      "Option held with the setting enabled emits precision and strips Option"
    )
    try expectDecision(
      decidePrecision(isOptionHeld: true, isOptionPrecisionEnabled: false),
      isPrecision: false,
      stripOption: false,
      "Option held with the setting disabled stays in intensity mode and forwards Option"
    )
    try expectDecision(
      decidePrecision(isOptionHeld: false, isOptionPrecisionEnabled: true),
      isPrecision: false,
      stripOption: false,
      "Option released keeps intensity mode and leaves flags untouched"
    )
  },

  TestCase(
    behavior:
      "given terminal precision then precision is the default and Option escapes to intensity"
  ) {
    try expectDecision(
      decidePrecision(isOptionHeld: false, isTerminalFrontmost: true),
      isPrecision: true,
      stripOption: false,
      "no Option in a terminal yields precision and needs no flag dance"
    )
    try expectDecision(
      decidePrecision(isOptionHeld: true, isTerminalFrontmost: true),
      isPrecision: false,
      stripOption: true,
      "Option held in a terminal escapes to the wheel step and strips Option from the synthesized event"
    )
    try expectDecision(
      decidePrecision(
        isOptionHeld: false,
        isTerminalFrontmost: true,
        isTerminalDefaultPrecisionEnabled: false
      ),
      isPrecision: false,
      stripOption: false,
      "terminal precision off falls back to normal app rules"
    )
    try expectDecision(
      decidePrecision(
        isOptionHeld: true,
        isOptionPrecisionEnabled: true,
        isTerminalFrontmost: true,
        isTerminalDefaultPrecisionEnabled: false
      ),
      isPrecision: true,
      stripOption: true,
      "terminal precision off still honors the Option precision setting"
    )
  },

  TestCase(
    behavior: "given non-discrete or ambiguous scrolling when rewriting then it drops the event"
  ) {
    try expectNil(
      ScrollRewriteCore.rewrite(scrollInput(deltaAxis1: 1, isContinuous: true)),
      "continuous scroll should not rewrite"
    )
    try expectNil(
      ScrollRewriteCore.rewrite(scrollInput(deltaAxis1: 1, hasPhase: true)),
      "phased scroll should not rewrite"
    )
    try expectNil(
      ScrollRewriteCore.rewrite(scrollInput(deltaAxis1: 1, deltaAxis2: 1)),
      "diagonal scroll should not rewrite"
    )
    try expectNil(
      ScrollRewriteCore.rewrite(scrollInput()),
      "zero-delta scroll should not rewrite"
    )
  },
]

private func expectRewrite(
  _ input: ScrollRewriteInput,
  _ expected: ScrollRewriteOutput,
  _ message: String
) throws {
  let output = try expectNotNil(ScrollRewriteCore.rewrite(input), message)
  try expectEqual(output.linesX, expected.linesX, "\(message): linesX")
  try expectEqual(output.linesY, expected.linesY, "\(message): linesY")
}

private func decidePrecision(
  isOptionHeld: Bool,
  isOptionPrecisionEnabled: Bool = false,
  isTerminalFrontmost: Bool = false,
  isTerminalDefaultPrecisionEnabled: Bool = true
) -> ScrollRewriteCore.PrecisionDecision {
  ScrollRewriteCore.decidePrecision(
    isOptionHeld: isOptionHeld,
    isOptionPrecisionEnabled: isOptionPrecisionEnabled,
    isTerminalFrontmost: isTerminalFrontmost,
    isTerminalDefaultPrecisionEnabled: isTerminalDefaultPrecisionEnabled
  )
}

private func expectDecision(
  _ actual: ScrollRewriteCore.PrecisionDecision,
  isPrecision: Bool,
  stripOption: Bool,
  _ message: String
) throws {
  try expectEqual(actual.isPrecision, isPrecision, "\(message): isPrecision")
  try expectEqual(actual.stripOption, stripOption, "\(message): stripOption")
}

private func scrollInput(
  deltaAxis1: Int32 = 0,
  deltaAxis2: Int32 = 0,
  intensity: ScrollIntensity = .slow,
  isContinuous: Bool = false,
  hasPhase: Bool = false,
  isPrecision: Bool = false,
  isTrackpadStyleScrollingEnabled: Bool = true
) -> ScrollRewriteInput {
  ScrollRewriteInput(
    deltaAxis1: deltaAxis1,
    deltaAxis2: deltaAxis2,
    intensity: intensity,
    isContinuous: isContinuous,
    hasPhase: hasPhase,
    isPrecision: isPrecision,
    isTrackpadStyleScrollingEnabled: isTrackpadStyleScrollingEnabled
  )
}
