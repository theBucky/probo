package enum ScrollAxis: Equatable, Sendable {
  case vertical
  case horizontal
}

package enum WheelDirection: Int32, Equatable, Sendable {
  case negative = -1
  case positive = 1
}

// A wheel notch moves exactly one axis; diagonal and zero deltas have no notch.
package struct WheelNotch: Equatable, Sendable {
  package let axis: ScrollAxis
  package let direction: WheelDirection

  package init(axis: ScrollAxis, direction: WheelDirection) {
    self.axis = axis
    self.direction = direction
  }

  init?(verticalDelta: Int32, horizontalDelta: Int32) {
    switch (verticalDelta.signum(), horizontalDelta.signum()) {
    case (-1, 0): self.init(axis: .vertical, direction: .negative)
    case (1, 0): self.init(axis: .vertical, direction: .positive)
    case (0, -1): self.init(axis: .horizontal, direction: .negative)
    case (0, 1): self.init(axis: .horizontal, direction: .positive)
    default: return nil
    }
  }
}

package struct ScrollStep: Equatable, Sendable {
  package let axis: ScrollAxis
  package let lines: Int32
  package let stripsOption: Bool
}

extension InputConfiguration {
  package func scrollStep(
    for notch: WheelNotch,
    isOptionHeld: Bool,
    isTerminalFrontmost: Bool
  ) -> ScrollStep {
    let stripsOption: Bool
    let stepLines: Int32
    if isTerminalOptimizationEnabled && isTerminalFrontmost {
      stripsOption = isOptionHeld
      stepLines = isOptionHeld ? wheelStep.lines : 1
    } else if isOptionPrecisionEnabled && isOptionHeld {
      stripsOption = true
      stepLines = 1
    } else {
      stripsOption = false
      stepLines = wheelStep.lines
    }

    let sign = notch.direction.rawValue * (isTrackpadStyleScrollingEnabled ? 1 : -1)
    return ScrollStep(axis: notch.axis, lines: sign * stepLines, stripsOption: stripsOption)
  }
}
