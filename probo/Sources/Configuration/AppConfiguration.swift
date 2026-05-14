struct AppConfiguration: Equatable, Codable, Sendable {
  static let defaultValue = Self(
    isEnabled: true,
    intensity: .slow,
    isLookUpEnabled: true,
    isOptionPrecisionEnabled: false,
    isTerminalOptimizationEnabled: true,
    isTrackpadStyleScrollingEnabled: false,
    preventsAutomaticSleep: false
  )

  var isEnabled: Bool
  var intensity: ScrollIntensity
  var isLookUpEnabled: Bool
  var isOptionPrecisionEnabled: Bool
  var isTerminalOptimizationEnabled: Bool
  var isTrackpadStyleScrollingEnabled: Bool
  var preventsAutomaticSleep: Bool
}
