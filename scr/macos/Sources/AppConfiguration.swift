enum ScrollIntensity: Int, CaseIterable, Sendable {
    case slow = 0
    case medium = 1

    var runtimeValue: UInt8 { UInt8(rawValue) }
}

struct AppConfiguration: Equatable, Sendable {
    var isEnabled: Bool
    var intensity: ScrollIntensity
}
