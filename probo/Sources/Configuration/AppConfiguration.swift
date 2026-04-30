enum ScrollIntensity: Int, CaseIterable, Sendable {
  case slow = 0
  case medium = 1

  var title: String {
    switch self {
    case .slow: "Slow"
    case .medium: "Medium"
    }
  }
}

struct AppConfiguration: Equatable, Sendable {
  static let defaultValue = Self(
    isEnabled: true,
    intensity: .slow,
    isLookUpEnabled: true,
    isPrecisionScrollEnabled: false,
    isTrackpadStyleScrollingEnabled: true
  )

  var isEnabled: Bool
  var intensity: ScrollIntensity
  var isLookUpEnabled: Bool
  var isPrecisionScrollEnabled: Bool
  var isTrackpadStyleScrollingEnabled: Bool
}
