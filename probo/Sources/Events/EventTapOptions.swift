struct EventTapOptions: Sendable {
  private static let lookUpBit: UInt32 = 1 << 0
  private static let optionPrecisionBit: UInt32 = 1 << 1
  private static let terminalOptimizationBit: UInt32 = 1 << 2
  private static let trackpadStyleScrollingBit: UInt32 = 1 << 3
  private static let mediumIntensityBit: UInt32 = 1 << 4

  let isLookUpEnabled: Bool
  let isOptionPrecisionEnabled: Bool
  let isTerminalOptimizationEnabled: Bool
  let isTrackpadStyleScrollingEnabled: Bool
  let intensity: ScrollIntensity

  init(configuration: AppConfiguration) {
    isLookUpEnabled = configuration.isLookUpEnabled
    isOptionPrecisionEnabled = configuration.isOptionPrecisionEnabled
    isTerminalOptimizationEnabled = configuration.isTerminalOptimizationEnabled
    isTrackpadStyleScrollingEnabled = configuration.isTrackpadStyleScrollingEnabled
    intensity = configuration.intensity
  }

  init(rawValue: UInt32) {
    isLookUpEnabled = rawValue & Self.lookUpBit != 0
    isOptionPrecisionEnabled = rawValue & Self.optionPrecisionBit != 0
    isTerminalOptimizationEnabled = rawValue & Self.terminalOptimizationBit != 0
    isTrackpadStyleScrollingEnabled = rawValue & Self.trackpadStyleScrollingBit != 0
    intensity = rawValue & Self.mediumIntensityBit == 0 ? .slow : .medium
  }

  var rawValue: UInt32 {
    var value: UInt32 = 0
    if isLookUpEnabled { value |= Self.lookUpBit }
    if isOptionPrecisionEnabled { value |= Self.optionPrecisionBit }
    if isTerminalOptimizationEnabled { value |= Self.terminalOptimizationBit }
    if isTrackpadStyleScrollingEnabled { value |= Self.trackpadStyleScrollingBit }
    if intensity == .medium { value |= Self.mediumIntensityBit }
    return value
  }
}
