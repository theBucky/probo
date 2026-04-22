import ApplicationServices

final class ScrollEventSynthesizer {
    private let marker: Int64
    private let source = CGEventSource(stateID: .hidSystemState)

    init(marker: Int64) {
        self.marker = marker
    }

    func makeReplacement(location: CGPoint, flags: CGEventFlags, linesX: Int32, linesY: Int32) -> CGEvent? {
        let wheelCount: UInt32 = linesX == 0 ? 1 : 2
        guard let replacement = CGEvent(
            scrollWheelEvent2Source: source,
            units: .line,
            wheelCount: wheelCount,
            wheel1: linesY,
            wheel2: linesX,
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
