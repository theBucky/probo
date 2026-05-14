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
  struct PrecisionDecision: Equatable, Sendable {
    var isPrecision: Bool
    var stripOption: Bool
  }

  static func decidePrecision(
    isOptionHeld: Bool,
    isOptionPrecisionEnabled: Bool,
    isTerminalOptimizationActive: Bool
  ) -> PrecisionDecision {
    if isTerminalOptimizationActive {
      return PrecisionDecision(
        isPrecision: !isOptionHeld,
        stripOption: isOptionHeld
      )
    }

    return PrecisionDecision(
      isPrecision: isOptionPrecisionEnabled && isOptionHeld,
      stripOption: isOptionPrecisionEnabled && isOptionHeld
    )
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
