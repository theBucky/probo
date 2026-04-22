import Foundation

enum ScrollIntensity: Int {
    case slow = 0
    case medium = 1

    var runtimeValue: UInt8 {
        UInt8(rawValue)
    }
}

struct AppConfiguration: Equatable {
    var isEnabled: Bool
    var intensity: ScrollIntensity
}
