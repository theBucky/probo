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
