enum ScrollIntensity: Int, CaseIterable, Sendable {
  case slow = 0
  case medium = 1

  var runtimeValue: UInt8 { UInt8(rawValue) }
}

struct AppConfiguration: Equatable, Sendable {
  static let defaultValue = Self(isEnabled: true, intensity: .slow, isLookUpEnabled: true)

  var isEnabled: Bool
  var intensity: ScrollIntensity
  var isLookUpEnabled: Bool
}
