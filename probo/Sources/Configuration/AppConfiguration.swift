enum ScrollIntensity: Int, CaseIterable, Sendable {
  case slow = 0
  case medium = 1
}

struct AppConfiguration: Equatable, Sendable {
  static let defaultValue = Self(
    isEnabled: true,
    intensity: .slow,
    isLookUpEnabled: true,
    isPrecisionScrollEnabled: false
  )

  var isEnabled: Bool
  var intensity: ScrollIntensity
  var isLookUpEnabled: Bool
  var isPrecisionScrollEnabled: Bool
}
