import ApplicationServices
import Foundation

final class EventTapController {
    private static let synthMarker: Int64 = 0x50524F424F

    struct Status: Equatable {
        var isInstalled: Bool
        var isEnabled: Bool
    }

    private let synth = ScrollEventSynthesizer(marker: EventTapController.synthMarker)
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var isEnabled = false

    var intensity: ScrollIntensity = .slow
    var onStatusChange: ((Status) -> Void)?

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled

        guard enabled else {
            if let eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: false)
            }
            notifyStatus()
            return
        }

        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: true)
            notifyStatus()
            return
        }

        let mask = CGEventMask(1 << CGEventType.scrollWheel.rawValue)
        let callback: CGEventTapCallBack = { _, type, event, userInfo in
            guard let userInfo else {
                return Unmanaged.passUnretained(event)
            }

            let controller = Unmanaged<EventTapController>.fromOpaque(userInfo).takeUnretainedValue()
            return controller.handle(type: type, event: event)
        }

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            notifyStatus()
            return
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        if let runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        CGEvent.tapEnable(tap: tap, enable: true)
        notifyStatus()
    }

    func teardown() {
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        runLoopSource = nil
        eventTap = nil
        isEnabled = false
        notifyStatus()
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        let pass = Unmanaged.passUnretained(event)

        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let eventTap, isEnabled {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
            return pass
        }

        guard type == .scrollWheel, isEnabled else {
            return pass
        }

        if event.getIntegerValueField(.eventSourceUserData) == Self.synthMarker {
            return pass
        }

        let isContinuous = event.getIntegerValueField(.scrollWheelEventIsContinuous) != 0
        let hasPhase = !isContinuous && (
            event.getIntegerValueField(.scrollWheelEventScrollPhase) != 0 ||
            event.getIntegerValueField(.scrollWheelEventMomentumPhase) != 0
        )

        let deltaAxis1 = Int32(truncatingIfNeeded: event.getIntegerValueField(.scrollWheelEventDeltaAxis1))
        let deltaAxis2 = Int32(truncatingIfNeeded: event.getIntegerValueField(.scrollWheelEventDeltaAxis2))

        guard let output = RuntimeBridge.rewrite(
            deltaAxis1: deltaAxis1,
            deltaAxis2: deltaAxis2,
            intensity: intensity,
            isContinuous: isContinuous,
            hasPhase: hasPhase
        ) else {
            return pass
        }

        guard let replacement = synth.makeReplacement(
            location: event.location,
            flags: event.flags,
            linesX: output.linesX,
            linesY: output.linesY
        ) else {
            return pass
        }

        replacement.post(tap: .cgSessionEventTap)
        return nil
    }

    private func notifyStatus() {
        onStatusChange?(Status(isInstalled: eventTap != nil, isEnabled: isEnabled && eventTap != nil))
    }
}
