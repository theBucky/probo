struct AppConfiguration: Equatable, Sendable {
  static let defaultValue = Self(
    isEnabled: true,
    intensity: .slow,
    isLookUpEnabled: true,
    isOptionPrecisionEnabled: false,
    isTerminalDefaultPrecisionEnabled: true,
    isTrackpadStyleScrollingEnabled: false,
    preventsAutomaticSleep: false
  )

  var isEnabled: Bool
  var intensity: ScrollIntensity
  var isLookUpEnabled: Bool
  var isOptionPrecisionEnabled: Bool
  var isTerminalDefaultPrecisionEnabled: Bool
  var isTrackpadStyleScrollingEnabled: Bool
  var preventsAutomaticSleep: Bool
}
