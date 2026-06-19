package enum ScrollRewriteCore {
  package struct PrecisionDecision: Equatable, Sendable {
    package var isPrecision: Bool
    package var stripOption: Bool
  }

  package static func decidePrecision(
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

  // Drops continuous, phased, diagonal, and zero-delta events per the project invariant.
  package static func rewrite(
    deltaAxis1: Int32,
    deltaAxis2: Int32,
    intensity: ScrollIntensity,
    isContinuous: Bool,
    hasPhase: Bool,
    isPrecision: Bool,
    isTrackpadStyleScrollingEnabled: Bool
  ) -> (linesX: Int32, linesY: Int32)? {
    if isContinuous || hasPhase { return nil }
    if (deltaAxis1 != 0) == (deltaAxis2 != 0) { return nil }

    let stepLines: Int32 = isPrecision ? 1 : intensity.lines
    let direction: Int32 = isTrackpadStyleScrollingEnabled ? 1 : -1
    return (
      linesX: deltaAxis2.signum() * stepLines * direction,
      linesY: deltaAxis1.signum() * stepLines * direction
    )
  }
}
