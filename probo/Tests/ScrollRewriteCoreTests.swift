let scrollRewriteCoreTests: [TestCase] = [
  TestCase(behavior: "given discrete wheel notches when rewriting then it emits signed line steps")
  {
    try expectRewrite(
      scrollInput(deltaAxis1: 1),
      ScrollRewriteOutput(linesX: 0, linesY: 2),
      "slow vertical notch should emit two vertical lines"
    )
    try expectRewrite(
      scrollInput(deltaAxis1: -7, intensity: .medium),
      ScrollRewriteOutput(linesX: 0, linesY: -3),
      "medium reverse vertical notch should emit three signed lines"
    )
    try expectRewrite(
      scrollInput(deltaAxis2: -9, intensity: .medium),
      ScrollRewriteOutput(linesX: -3, linesY: 0),
      "medium horizontal notch should emit three signed horizontal lines"
    )
  },

  TestCase(behavior: "given precision mode when rewriting then it emits one signed line") {
    let output = try expectNotNil(
      ScrollRewriteCore.rewrite(
        scrollInput(deltaAxis1: -1, intensity: .medium, isPrecision: true)),
      "precision notch should rewrite"
    )

    try expectEqual(output.linesY, -1, "precision mode should override intensity")
  },

  TestCase(behavior: "given unsupported wheel events when rewriting then it drops them") {
    try expectNil(
      ScrollRewriteCore.rewrite(scrollInput(deltaAxis1: 1, isContinuous: true)),
      "continuous scroll should pass through"
    )
    try expectNil(
      ScrollRewriteCore.rewrite(scrollInput(deltaAxis1: 1, hasPhase: true)),
      "phased scroll should pass through"
    )
    try expectNil(
      ScrollRewriteCore.rewrite(scrollInput(deltaAxis1: 1, deltaAxis2: 1)),
      "diagonal scroll should pass through"
    )
    try expectNil(
      ScrollRewriteCore.rewrite(scrollInput()),
      "zero-delta scroll should pass through"
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

private func scrollInput(
  deltaAxis1: Int32 = 0,
  deltaAxis2: Int32 = 0,
  intensity: ScrollIntensity = .slow,
  isContinuous: Bool = false,
  hasPhase: Bool = false,
  isPrecision: Bool = false
) -> ScrollRewriteInput {
  ScrollRewriteInput(
    deltaAxis1: deltaAxis1,
    deltaAxis2: deltaAxis2,
    intensity: intensity,
    isContinuous: isContinuous,
    hasPhase: hasPhase,
    isPrecision: isPrecision
  )
}
