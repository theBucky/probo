enum ScrollIntensity: Int, CaseIterable, Sendable {
  case slow = 0
  case medium = 1
}

enum ScrollStepMode: Int, Sendable {
  case classic = 0
  case highFrequency = 1
}

struct AppConfiguration: Equatable, Sendable {
  static let defaultValue = Self(
    isEnabled: true,
    intensity: .slow,
    stepMode: .highFrequency,
    isLookUpEnabled: true,
    isPrecisionScrollEnabled: false
  )

  var isEnabled: Bool
  var intensity: ScrollIntensity
  var stepMode: ScrollStepMode
  var isLookUpEnabled: Bool
  var isPrecisionScrollEnabled: Bool
}
