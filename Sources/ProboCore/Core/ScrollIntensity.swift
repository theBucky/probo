package enum ScrollIntensity: Int, CaseIterable, Codable, Sendable {
  case slow = 0
  case medium = 1

  package var lines: Int32 {
    switch self {
    case .slow: 2
    case .medium: 3
    }
  }
}
