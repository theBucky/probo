struct AppConfiguration: Equatable, Sendable {
  static let defaultValue = Self(
    isEnabled: true,
    intensity: .slow,
    isLookUpEnabled: true,
    isPrecisionScrollEnabled: false,
    isTrackpadStyleScrollingEnabled: false
  )

  var isEnabled: Bool
  var intensity: ScrollIntensity
  var isLookUpEnabled: Bool
  var isPrecisionScrollEnabled: Bool
  var isTrackpadStyleScrollingEnabled: Bool
}
