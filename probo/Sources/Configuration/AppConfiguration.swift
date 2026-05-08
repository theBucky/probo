struct AppConfiguration: Equatable, Sendable {
  static let defaultValue = Self(
    isEnabled: true,
    intensity: .slow,
    isLookUpEnabled: true,
    isPrecisionScrollEnabled: false,
    isTerminalPrecisionEnabled: true,
    isTrackpadStyleScrollingEnabled: false
  )

  var isEnabled: Bool
  var intensity: ScrollIntensity
  var isLookUpEnabled: Bool
  var isPrecisionScrollEnabled: Bool
  var isTerminalPrecisionEnabled: Bool
  var isTrackpadStyleScrollingEnabled: Bool
}
