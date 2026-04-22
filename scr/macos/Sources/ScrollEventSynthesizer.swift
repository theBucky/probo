import ApplicationServices
import Foundation

final class ScrollEventSynthesizer {
    private let marker: Int64
    private let source = CGEventSource(stateID: .hidSystemState)

    init(marker: Int64) {
        self.marker = marker
    }

    func makeReplacement(location: CGPoint, flags: CGEventFlags, dx: Int32, dy: Int32) -> CGEvent? {
        let wheelCount: UInt32 = dx == 0 ? 1 : 2
        guard let replacement = CGEvent(
            scrollWheelEvent2Source: source,
            units: .pixel,
            wheelCount: wheelCount,
            wheel1: dy,
            wheel2: dx,
            wheel3: 0
        ) else {
            return nil
        }

        replacement.location = location
        replacement.flags = flags
        replacement.setIntegerValueField(.eventSourceUserData, value: marker)
        return replacement
    }
}
