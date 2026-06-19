package enum ScrollIntensity: Int, CaseIterable, Codable, Sendable {
  case slow = 0
  case medium = 1

  package var title: String {
    switch self {
    case .slow: "Slow"
    case .medium: "Medium"
    }
  }

  package var lines: Int32 {
    switch self {
    case .slow: 2
    case .medium: 3
    }
  }
}
