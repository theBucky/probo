package enum WheelStep: Int, CaseIterable, Sendable {
  case slow = 0
  case medium = 1

  package var lines: Int32 {
    switch self {
    case .slow: 2
    case .medium: 3
    }
  }
}

package enum ScrollVerdict: Equatable, Sendable {
  case drop
  case emit(linesX: Int32, linesY: Int32, stripsOption: Bool)
}

package func decideScroll(
  verticalDelta: Int32,
  horizontalDelta: Int32,
  isOptionHeld: Bool,
  isTerminalFrontmost: Bool,
  options: TapOptions
) -> ScrollVerdict {
  if (verticalDelta != 0) == (horizontalDelta != 0) { return .drop }

  let stripsOption: Bool
  let stepLines: Int32
  if options.isTerminalOptimizationEnabled && isTerminalFrontmost {
    stripsOption = isOptionHeld
    stepLines = isOptionHeld ? options.stepLines : 1
  } else if options.isOptionPrecisionEnabled && isOptionHeld {
    stripsOption = true
    stepLines = 1
  } else {
    stripsOption = false
    stepLines = options.stepLines
  }

  let direction: Int32 = options.isTrackpadStyleScrollingEnabled ? 1 : -1
  let step = stepLines * direction
  return .emit(
    linesX: horizontalDelta.signum() * step,
    linesY: verticalDelta.signum() * step,
    stripsOption: stripsOption
  )
}
