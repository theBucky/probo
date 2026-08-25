// Bit-packed so the event tap can publish one coherent configuration to its callback thread.
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

  package init(configuration: InputConfiguration) {
    var value = UInt32(configuration.wheelStep.lines) << Self.stepLinesShift
    if configuration.isLookUpEnabled { value |= Self.lookUpBit }
    if configuration.isOptionPrecisionEnabled { value |= Self.optionPrecisionBit }
    if configuration.isTerminalOptimizationEnabled { value |= Self.terminalOptimizationBit }
    if configuration.isTrackpadStyleScrollingEnabled {
      value |= Self.trackpadStyleScrollingBit
    }
    rawValue = value
  }

  package var isLookUpEnabled: Bool { rawValue & Self.lookUpBit != 0 }
  package var isOptionPrecisionEnabled: Bool { rawValue & Self.optionPrecisionBit != 0 }
  package var isTerminalOptimizationEnabled: Bool {
    rawValue & Self.terminalOptimizationBit != 0
  }
  package var isTrackpadStyleScrollingEnabled: Bool {
    rawValue & Self.trackpadStyleScrollingBit != 0
  }
  package var stepLines: Int32 { Int32((rawValue & Self.stepLinesMask) >> Self.stepLinesShift) }
}

package enum WheelDirection: Int32, Equatable, Sendable {
  case negative = -1
  case positive = 1
}

package enum WheelNotch: Equatable, Sendable {
  case vertical(WheelDirection)
  case horizontal(WheelDirection)

  package init?(verticalDelta: Int32, horizontalDelta: Int32) {
    switch (verticalDelta.signum(), horizontalDelta.signum()) {
    case (-1, 0): self = .vertical(.negative)
    case (1, 0): self = .vertical(.positive)
    case (0, -1): self = .horizontal(.negative)
    case (0, 1): self = .horizontal(.positive)
    default: return nil
    }
  }
}

package enum ScrollOutput: Equatable, Sendable {
  case vertical(lines: Int32, stripsOption: Bool)
  case horizontal(lines: Int32, stripsOption: Bool)
}

package func resolveScroll(
  _ notch: WheelNotch,
  isOptionHeld: Bool,
  isTerminalFrontmost: Bool,
  options: TapOptions
) -> ScrollOutput {
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

  let lines = stepLines * (options.isTrackpadStyleScrollingEnabled ? 1 : -1)
  return switch notch {
  case .vertical(let wheelDirection):
    .vertical(lines: wheelDirection.rawValue * lines, stripsOption: stripsOption)
  case .horizontal(let wheelDirection):
    .horizontal(lines: wheelDirection.rawValue * lines, stripsOption: stripsOption)
  }
}
