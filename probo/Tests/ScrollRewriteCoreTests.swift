let scrollRewriteCoreTests: [TestCase] = [
  TestCase(
    behavior:
      "given discrete wheel notches when rewriting then it emits configured fixed line steps"
  ) {
    try expectRewrite(deltaAxis1: 1, linesX: 0, linesY: 2, "slow vertical notch")
    try expectRewrite(
      deltaAxis1: -42,
      linesX: 0,
      linesY: -2,
      "large source delta still maps to one slow step"
    )
    try expectRewrite(
      deltaAxis2: -9,
      intensity: .medium,
      linesX: -3,
      linesY: 0,
      "medium horizontal notch"
    )
    try expectRewrite(
      deltaAxis2: Int32.min,
      intensity: .medium,
      linesX: -3,
      linesY: 0,
      "minimum source delta still maps to one medium step"
    )
  },

  TestCase(
    behavior: "given precision mode when rewriting then it emits one line regardless of intensity"
  ) {
    try expectRewrite(
      deltaAxis1: -1,
      intensity: .slow,
      isPrecision: true,
      linesX: 0,
      linesY: -1,
      "precision mode ignores slow intensity"
    )
    try expectRewrite(
      deltaAxis1: -1,
      intensity: .medium,
      isPrecision: true,
      linesX: 0,
      linesY: -1,
      "precision mode ignores medium intensity"
    )
  },

  TestCase(
    behavior:
      "given trackpad-style scrolling is disabled when rewriting then it reverses line direction"
  ) {
    try expectRewrite(
      deltaAxis1: 1,
      isTrackpadStyleScrollingEnabled: false,
      linesX: 0,
      linesY: -2,
      "vertical direction"
    )
    try expectRewrite(
      deltaAxis2: -9,
      intensity: .medium,
      isTrackpadStyleScrollingEnabled: false,
      linesX: 3,
      linesY: 0,
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
      "given terminal optimization then one line is the default and Option escapes to intensity"
  ) {
    try expectDecision(
      decidePrecision(isOptionHeld: false, isTerminalOptimizationActive: true),
      isPrecision: true,
      stripOption: false,
      "no Option in a terminal yields precision and needs no flag dance"
    )
    try expectDecision(
      decidePrecision(isOptionHeld: true, isTerminalOptimizationActive: true),
      isPrecision: false,
      stripOption: true,
      "Option held in a terminal escapes to the wheel step and strips Option from the synthesized event"
    )
    try expectDecision(
      decidePrecision(isOptionHeld: false, isTerminalOptimizationActive: false),
      isPrecision: false,
      stripOption: false,
      "terminal optimization off falls back to normal app rules"
    )
    try expectDecision(
      decidePrecision(
        isOptionHeld: true,
        isOptionPrecisionEnabled: true,
        isTerminalOptimizationActive: false
      ),
      isPrecision: true,
      stripOption: true,
      "terminal optimization off still honors the Option precision setting"
    )
  },

  TestCase(
    behavior: "given non-discrete or ambiguous scrolling when rewriting then the core drops it"
  ) {
    try expectNil(
      rewrite(deltaAxis1: 1, isContinuous: true),
      "continuous scroll must not rewrite"
    )
    try expectNil(
      rewrite(deltaAxis1: 1, hasPhase: true),
      "phased scroll must not rewrite"
    )
    try expectNil(
      rewrite(deltaAxis1: 1, deltaAxis2: 1),
      "diagonal scroll must not rewrite"
    )
    try expectNil(
      rewrite(),
      "zero-delta scroll must not rewrite"
    )
  },
]

private func rewrite(
  deltaAxis1: Int32 = 0,
  deltaAxis2: Int32 = 0,
  intensity: ScrollIntensity = .slow,
  isContinuous: Bool = false,
  hasPhase: Bool = false,
  isPrecision: Bool = false,
  isTrackpadStyleScrollingEnabled: Bool = true
) -> (linesX: Int32, linesY: Int32)? {
  ScrollRewriteCore.rewrite(
    deltaAxis1: deltaAxis1,
    deltaAxis2: deltaAxis2,
    intensity: intensity,
    isContinuous: isContinuous,
    hasPhase: hasPhase,
    isPrecision: isPrecision,
    isTrackpadStyleScrollingEnabled: isTrackpadStyleScrollingEnabled
  )
}

private func expectRewrite(
  deltaAxis1: Int32 = 0,
  deltaAxis2: Int32 = 0,
  intensity: ScrollIntensity = .slow,
  isPrecision: Bool = false,
  isTrackpadStyleScrollingEnabled: Bool = true,
  linesX: Int32,
  linesY: Int32,
  _ message: String
) throws {
  let output = try expectNotNil(
    rewrite(
      deltaAxis1: deltaAxis1,
      deltaAxis2: deltaAxis2,
      intensity: intensity,
      isPrecision: isPrecision,
      isTrackpadStyleScrollingEnabled: isTrackpadStyleScrollingEnabled
    ),
    message
  )
  try expectEqual(output.linesX, linesX, "\(message): linesX")
  try expectEqual(output.linesY, linesY, "\(message): linesY")
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
) throws {
  try expectEqual(actual.isPrecision, isPrecision, "\(message): isPrecision")
  try expectEqual(actual.stripOption, stripOption, "\(message): stripOption")
}
