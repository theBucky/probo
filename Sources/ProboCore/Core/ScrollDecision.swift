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

// Bit-packed so the event tap can publish one atomic UInt32 to its callback thread.
package struct TapOptions: Equatable, Sendable {
  private static let lookUpBit: UInt32 = 1 << 0
  private static let optionPrecisionBit: UInt32 = 1 << 1
  private static let terminalOptimizationBit: UInt32 = 1 << 2
  private static let trackpadStyleScrollingBit: UInt32 = 1 << 3
  private static let stepLinesShift: UInt32 = 8
  private static let stepLinesMask: UInt32 = 0xFF << stepLinesShift

  package let rawValue: UInt32

  package init(rawValue: UInt32) {
    self.rawValue = rawValue
  }

  package init(
    isLookUpEnabled: Bool,
    isOptionPrecisionEnabled: Bool,
    isTerminalOptimizationEnabled: Bool,
    isTrackpadStyleScrollingEnabled: Bool,
    stepLines: Int32
  ) {
    var value = UInt32(stepLines) << Self.stepLinesShift
    if isLookUpEnabled { value |= Self.lookUpBit }
    if isOptionPrecisionEnabled { value |= Self.optionPrecisionBit }
    if isTerminalOptimizationEnabled { value |= Self.terminalOptimizationBit }
    if isTrackpadStyleScrollingEnabled { value |= Self.trackpadStyleScrollingBit }
    rawValue = value
  }

  package var isLookUpEnabled: Bool { rawValue & Self.lookUpBit != 0 }
  package var isOptionPrecisionEnabled: Bool { rawValue & Self.optionPrecisionBit != 0 }
  package var isTerminalOptimizationEnabled: Bool { rawValue & Self.terminalOptimizationBit != 0 }
  package var isTrackpadStyleScrollingEnabled: Bool {
    rawValue & Self.trackpadStyleScrollingBit != 0
  }
  package var stepLines: Int32 { Int32((rawValue & Self.stepLinesMask) >> Self.stepLinesShift) }
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
