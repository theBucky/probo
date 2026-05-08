struct ScrollRewriteInput: Sendable {
  var deltaAxis1: Int32
  var deltaAxis2: Int32
  var intensity: ScrollIntensity
  var isContinuous: Bool
  var hasPhase: Bool
  var isPrecision: Bool
  var isTrackpadStyleScrollingEnabled: Bool
}

struct ScrollRewriteOutput: Sendable {
  var linesX: Int32
  var linesY: Int32
}

enum ScrollRewriteCore {
  private static let precisionStepLines: Int32 = 1
  private static let slowStepLines: Int32 = 2
  private static let mediumStepLines: Int32 = 3

  struct ScrollDecision: Equatable, Sendable {
    var isPrecision: Bool
    var stripOption: Bool
  }

  // Terminal mode inverts Option: precision by default, Option escapes to intensity.
  // Stripping keeps the target app from seeing alt-scroll layered on top of our override.
  static func decide(
    isOptionHeld: Bool,
    isPrecisionScrollEnabled: Bool,
    isTerminalFrontmost: Bool,
    isTerminalPrecisionEnabled: Bool
  ) -> ScrollDecision {
    let terminalMode = isTerminalFrontmost && isTerminalPrecisionEnabled
    let isPrecision =
      terminalMode ? !isOptionHeld : (isPrecisionScrollEnabled && isOptionHeld)
    let stripOption = isOptionHeld && (terminalMode || isPrecisionScrollEnabled)
    return ScrollDecision(isPrecision: isPrecision, stripOption: stripOption)
  }

  static func rewrite(_ input: ScrollRewriteInput) -> ScrollRewriteOutput? {
    if input.isContinuous || input.hasPhase {
      return nil
    }
    if (input.deltaAxis1 != 0) == (input.deltaAxis2 != 0) {
      return nil
    }

    let stepLines = stepLines(for: input.intensity, isPrecision: input.isPrecision)
    let direction: Int32 = input.isTrackpadStyleScrollingEnabled ? 1 : -1
    return ScrollRewriteOutput(
      linesX: input.deltaAxis2.signum() * stepLines * direction,
      linesY: input.deltaAxis1.signum() * stepLines * direction
    )
  }

  private static func stepLines(for intensity: ScrollIntensity, isPrecision: Bool) -> Int32 {
    if isPrecision {
      return precisionStepLines
    }
    switch intensity {
    case .slow:
      return slowStepLines
    case .medium:
      return mediumStepLines
    }
  }

}
