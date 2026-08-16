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

package struct InputConfiguration: Equatable, Sendable {
  package var wheelStep: WheelStep
  package var isLookUpEnabled: Bool
  package var isOptionPrecisionEnabled: Bool
  package var isTerminalOptimizationEnabled: Bool
  package var isTrackpadStyleScrollingEnabled: Bool

  package init(
    wheelStep: WheelStep = .slow,
    isLookUpEnabled: Bool = true,
    isOptionPrecisionEnabled: Bool = false,
    isTerminalOptimizationEnabled: Bool = true,
    isTrackpadStyleScrollingEnabled: Bool = false
  ) {
    self.wheelStep = wheelStep
    self.isLookUpEnabled = isLookUpEnabled
    self.isOptionPrecisionEnabled = isOptionPrecisionEnabled
    self.isTerminalOptimizationEnabled = isTerminalOptimizationEnabled
    self.isTrackpadStyleScrollingEnabled = isTrackpadStyleScrollingEnabled
  }
}
