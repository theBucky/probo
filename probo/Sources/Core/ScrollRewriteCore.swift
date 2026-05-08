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

    let stepLines: Int32 = input.isPrecision ? 1 : input.intensity.lines
    let direction: Int32 = input.isTrackpadStyleScrollingEnabled ? 1 : -1
    return ScrollRewriteOutput(
      linesX: input.deltaAxis2.signum() * stepLines * direction,
      linesY: input.deltaAxis1.signum() * stepLines * direction
    )
  }
}
