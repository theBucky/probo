@preconcurrency import ApplicationServices

@MainActor
final class EventTapController {
  // ASCII "PROBO" — tags synthesized events so the tap can skip its own output.
  private static let synthMarker: Int64 = 0x50_524F_424F

  struct Status: Equatable, Sendable {
    var isInstalled: Bool
    var isEnabled: Bool
  }

  private let scrollRewriter = ScrollEventRewriter(marker: EventTapController.synthMarker)
  private var eventTap: CFMachPort?
  private var runLoopSource: CFRunLoopSource?
  private var isEnabled = false
  private var status = Status(isInstalled: false, isEnabled: false)

  private var configuration = AppConfiguration.defaultValue
  var onStatusChange: ((Status) -> Void)?

  func apply(configuration: AppConfiguration) {
    self.configuration = configuration
  }

  func setEnabled(_ enabled: Bool) {
    isEnabled = enabled
    if enabled && eventTap == nil {
      installTap()
    }
    if let eventTap {
      CGEvent.tapEnable(tap: eventTap, enable: enabled)
    }
    notifyStatus()
  }

  func teardown() {
    if let runLoopSource {
      CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
    }
    if let eventTap {
      CFMachPortInvalidate(eventTap)
    }
    runLoopSource = nil
    eventTap = nil
    isEnabled = false
    notifyStatus()
  }

  private func installTap() {
    let mask =
      CGEventMask(1 << CGEventType.scrollWheel.rawValue)
      | CGEventMask(1 << CGEventType.otherMouseDown.rawValue)
      | CGEventMask(1 << CGEventType.otherMouseUp.rawValue)
    let callback: CGEventTapCallBack = { _, type, event, userInfo in
      guard let userInfo else { return Unmanaged.passUnretained(event) }
      let controller = Unmanaged<EventTapController>.fromOpaque(userInfo).takeUnretainedValue()
      return MainActor.assumeIsolated {
        controller.handle(type: type, event: event)
      }
    }

    guard
      let tap = CGEvent.tapCreate(
        tap: .cgSessionEventTap,
        place: .headInsertEventTap,
        options: .defaultTap,
        eventsOfInterest: mask,
        callback: callback,
        userInfo: Unmanaged.passUnretained(self).toOpaque()
      )
    else { return }

    let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
    CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
    eventTap = tap
    runLoopSource = source
  }

  private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
    let pass = Unmanaged.passUnretained(event)

    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
      if let eventTap, isEnabled {
        CGEvent.tapEnable(tap: eventTap, enable: true)
      }
      return pass
    }

    guard isEnabled else { return pass }

    switch type {
    case .otherMouseDown, .otherMouseUp:
      return consumeOtherMouse(type: type, event: event) ? nil : pass
    case .scrollWheel:
      return scrollRewriter.rewrite(event: event, configuration: configuration) ? nil : pass
    default:
      return pass
    }
  }

  private func consumeOtherMouse(type: CGEventType, event: CGEvent) -> Bool {
    guard configuration.isLookUpEnabled else { return false }
    return LookUpGesture.consume(type: type, event: event)
  }

  private func notifyStatus() {
    let currentStatus = Status(
      isInstalled: eventTap != nil, isEnabled: isEnabled && eventTap != nil)
    guard status != currentStatus else { return }
    status = currentStatus
    onStatusChange?(currentStatus)
  }
}
