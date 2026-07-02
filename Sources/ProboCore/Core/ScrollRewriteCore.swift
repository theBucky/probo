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

    let optionPrecision = isOptionPrecisionEnabled && isOptionHeld
    return PrecisionDecision(isPrecision: optionPrecision, stripOption: optionPrecision)
  }

  // Drops diagonal and zero-delta wheel events per the project invariant.
  package static func rewrite(
    verticalDelta: Int32,
    horizontalDelta: Int32,
    intensity: ScrollIntensity,
    isPrecision: Bool,
    isTrackpadStyleScrollingEnabled: Bool
  ) -> (linesX: Int32, linesY: Int32)? {
    if (verticalDelta != 0) == (horizontalDelta != 0) { return nil }

    let step: Int32 =
      (isPrecision ? 1 : intensity.lines) * (isTrackpadStyleScrollingEnabled ? 1 : -1)
    return (
      linesX: horizontalDelta.signum() * step,
      linesY: verticalDelta.signum() * step
    )
  }
}
