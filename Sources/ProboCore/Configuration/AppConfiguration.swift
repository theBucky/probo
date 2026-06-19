package struct AppConfiguration: Equatable, Codable, Sendable {
  package static let defaultValue = Self(
    isEnabled: true,
    intensity: .slow,
    isLookUpEnabled: true,
    isOptionPrecisionEnabled: false,
    isTerminalOptimizationEnabled: true,
    isTrackpadStyleScrollingEnabled: false,
    preventsAutomaticSleep: false
  )

  package var isEnabled: Bool
  package var intensity: ScrollIntensity
  package var isLookUpEnabled: Bool
  package var isOptionPrecisionEnabled: Bool
  package var isTerminalOptimizationEnabled: Bool
  package var isTrackpadStyleScrollingEnabled: Bool
  package var preventsAutomaticSleep: Bool
}
