let scrollRewriteCoreTests: [TestCase] = [
  TestCase(behavior: "given a slow vertical notch when rewriting then it emits two vertical lines")
  {
    let output = try expectNotNil(
      ScrollRewriteCore.rewrite(scrollInput(deltaAxis1: 1)),
      "vertical notch should rewrite"
    )

    try expectEqual(output.linesX, 0, "vertical notch should not emit horizontal lines")
    try expectEqual(output.linesY, 2, "slow notch should emit two lines")
  },

  TestCase(behavior: "given a medium reverse vertical notch when rewriting then it preserves sign")
  {
    let output = try expectNotNil(
      ScrollRewriteCore.rewrite(scrollInput(deltaAxis1: -7, intensity: .medium)),
      "reverse vertical notch should rewrite"
    )

    try expectEqual(output.linesX, 0, "reverse vertical notch should not emit horizontal lines")
    try expectEqual(output.linesY, -3, "medium notch should emit three signed lines")
  },

  TestCase(behavior: "given a horizontal notch when rewriting then it emits horizontal lines") {
    let output = try expectNotNil(
      ScrollRewriteCore.rewrite(
        scrollInput(deltaAxis1: 0, deltaAxis2: -9, intensity: .medium)),
      "horizontal notch should rewrite"
    )

    try expectEqual(output.linesX, -3, "horizontal notch should emit signed horizontal lines")
    try expectEqual(output.linesY, 0, "horizontal notch should not emit vertical lines")
  },

  TestCase(behavior: "given precision mode when rewriting then it emits one signed line") {
    let output = try expectNotNil(
      ScrollRewriteCore.rewrite(
        scrollInput(deltaAxis1: -1, intensity: .medium, isPrecision: true)),
      "precision notch should rewrite"
    )

    try expectEqual(output.linesY, -1, "precision mode should override intensity")
  },

  TestCase(behavior: "given a continuous event when rewriting then it drops the event") {
    try expectNil(
      ScrollRewriteCore.rewrite(scrollInput(deltaAxis1: 1, isContinuous: true)),
      "continuous scroll should pass through"
    )
  },

  TestCase(behavior: "given a phased event when rewriting then it drops the event") {
    try expectNil(
      ScrollRewriteCore.rewrite(scrollInput(deltaAxis1: 1, hasPhase: true)),
      "phased scroll should pass through"
    )
  },

  TestCase(behavior: "given a diagonal event when rewriting then it drops the event") {
    try expectNil(
      ScrollRewriteCore.rewrite(scrollInput(deltaAxis1: 1, deltaAxis2: 1)),
      "diagonal scroll should pass through"
    )
  },

  TestCase(behavior: "given a zero-delta event when rewriting then it drops the event") {
    try expectNil(
      ScrollRewriteCore.rewrite(scrollInput()),
      "zero-delta scroll should pass through"
    )
  },
]

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
