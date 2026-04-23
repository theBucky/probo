@preconcurrency import ApplicationServices
import Carbon.HIToolbox
import IOKit.hidsystem

// .maskAlternate alone leaves device-side bits set, so consumers reading raw flags still see option.
private extension CGEventFlags {
  static let leftOption = CGEventFlags(rawValue: UInt64(NX_DEVICELALTKEYMASK))
  static let rightOption = CGEventFlags(rawValue: UInt64(NX_DEVICERALTKEYMASK))
  static let allOption: CGEventFlags = [.maskAlternate, .leftOption, .rightOption]
}

@MainActor
final class EventTapController {
  private static let synthMarker: Int64 = 0x50_524F_424F
  private static let lookUpButtonNumber: Int64 = 3
  private static let lookUpKeyCode: CGKeyCode = 2
  private static let lookUpFlags: CGEventFlags = [.maskCommand, .maskControl]

  struct Status: Equatable, Sendable {
    var isInstalled: Bool
    var isEnabled: Bool
  }

  private let synth = ScrollEventSynthesizer(marker: EventTapController.synthMarker)
  private var eventTap: CFMachPort?
  private var runLoopSource: CFRunLoopSource?
  private var isEnabled = false

  private var configuration: AppConfiguration = .defaultValue
  var onStatusChange: ((Status) -> Void)?

  func apply(configuration: AppConfiguration) {
    self.configuration = configuration
  }

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
    else {
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

    guard isEnabled else { return pass }

    if type == .otherMouseDown || type == .otherMouseUp {
      return handleOtherMouse(type: type, event: event) ? nil : pass
    }

    guard type == .scrollWheel else { return pass }

    if event.getIntegerValueField(.eventSourceUserData) == Self.synthMarker {
      return pass
    }

    let isContinuous = event.getIntegerValueField(.scrollWheelEventIsContinuous) != 0
    let hasPhase =
      !isContinuous
      && (event.getIntegerValueField(.scrollWheelEventScrollPhase) != 0
        || event.getIntegerValueField(.scrollWheelEventMomentumPhase) != 0)

    let deltaAxis1 = Int32(
      truncatingIfNeeded: event.getIntegerValueField(.scrollWheelEventDeltaAxis1))
    let deltaAxis2 = Int32(
      truncatingIfNeeded: event.getIntegerValueField(.scrollWheelEventDeltaAxis2))
    let originalFlags = event.flags
    let isPrecision =
      configuration.isPrecisionScrollEnabled && originalFlags.contains(.maskAlternate)

    guard
      let output = RuntimeBridge.rewrite(
        deltaAxis1: deltaAxis1,
        deltaAxis2: deltaAxis2,
        intensity: configuration.intensity,
        isContinuous: isContinuous,
        hasPhase: hasPhase,
        isPrecision: isPrecision
      )
    else {
      return pass
    }

    let replacementFlags =
      isPrecision ? originalFlags.subtracting(.allOption) : originalFlags

    guard
      let replacement = synth.makeReplacement(
        location: event.location,
        flags: replacementFlags,
        linesX: output.linesX,
        linesY: output.linesY
      )
    else {
      return pass
    }

    if isPrecision {
      let optionKey: CGKeyCode =
        originalFlags.contains(.rightOption) ? CGKeyCode(kVK_RightOption) : CGKeyCode(kVK_Option)
      synth.makeFlagsChanged(flags: replacementFlags, keyCode: optionKey)?
        .post(tap: .cgSessionEventTap)
      replacement.post(tap: .cgSessionEventTap)
      synth.makeFlagsChanged(flags: originalFlags, keyCode: optionKey)?
        .post(tap: .cgSessionEventTap)
    } else {
      replacement.post(tap: .cgSessionEventTap)
    }
    return nil
  }

  private func handleOtherMouse(type: CGEventType, event: CGEvent) -> Bool {
    guard configuration.isLookUpEnabled else { return false }
    guard event.getIntegerValueField(.mouseEventButtonNumber) == Self.lookUpButtonNumber else {
      return false
    }

    if type == .otherMouseDown {
      postLookUpShortcut()
    }

    return true
  }

  private func postLookUpShortcut() {
    guard let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: Self.lookUpKeyCode, keyDown: true),
      let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: Self.lookUpKeyCode, keyDown: false)
    else {
      return
    }

    keyDown.flags = Self.lookUpFlags
    keyUp.flags = Self.lookUpFlags
    keyDown.post(tap: .cgSessionEventTap)
    keyUp.post(tap: .cgSessionEventTap)
  }

  private func notifyStatus() {
    onStatusChange?(Status(isInstalled: eventTap != nil, isEnabled: isEnabled && eventTap != nil))
  }
}
