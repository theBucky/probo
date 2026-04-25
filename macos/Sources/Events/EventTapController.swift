@preconcurrency import ApplicationServices
import Carbon.HIToolbox
import IOKit.hidsystem

// .maskAlternate alone leaves device-side bits set, so consumers reading raw flags still see option.
private extension CGEventFlags {
  static let leftOption = CGEventFlags(rawValue: UInt64(NX_DEVICELALTKEYMASK))
  static let rightOption = CGEventFlags(rawValue: UInt64(NX_DEVICERALTKEYMASK))
  static let allOption: CGEventFlags = [.maskAlternate, .leftOption, .rightOption]
}

// Look Up shortcut (Cmd+Ctrl+D) bound to mouse button 4.
private enum LookUpGesture {
  static let buttonNumber: Int64 = 3  // CGEvent button numbers are zero-indexed; mouse button 4
  static let keyCode = CGKeyCode(kVK_ANSI_D)
  static let flags: CGEventFlags = [.maskCommand, .maskControl]

  static func post() {
    guard
      let down = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true),
      let up = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false)
    else { return }
    down.flags = flags
    up.flags = flags
    down.post(tap: .cgSessionEventTap)
    up.post(tap: .cgSessionEventTap)
  }
}

@MainActor
final class EventTapController {
  // ASCII "PROBO" — tags synthesized events so the tap can skip its own output.
  private static let synthMarker: Int64 = 0x50_524F_424F

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
      return handleOtherMouse(type: type, event: event) ? nil : pass
    case .scrollWheel:
      return handleScroll(event: event) ? nil : pass
    default:
      return pass
    }
  }

  private func handleScroll(event: CGEvent) -> Bool {
    if event.getIntegerValueField(.eventSourceUserData) == Self.synthMarker {
      return false
    }

    let isContinuous = event.getIntegerValueField(.scrollWheelEventIsContinuous) != 0
    if isContinuous {
      return false
    }
    let hasPhase =
      event.getIntegerValueField(.scrollWheelEventScrollPhase) != 0
      || event.getIntegerValueField(.scrollWheelEventMomentumPhase) != 0
    if hasPhase {
      return false
    }
    let deltaAxis1 = Int32(
      truncatingIfNeeded: event.getIntegerValueField(.scrollWheelEventDeltaAxis1))
    let deltaAxis2 = Int32(
      truncatingIfNeeded: event.getIntegerValueField(.scrollWheelEventDeltaAxis2))
    let originalFlags = event.flags
    let isPrecision =
      configuration.isPrecisionScrollEnabled && originalFlags.contains(.maskAlternate)

    guard
      let output = ScrollRewriteCore.rewrite(
        ScrollRewriteInput(
          deltaAxis1: deltaAxis1,
          deltaAxis2: deltaAxis2,
          intensity: configuration.intensity,
          isContinuous: isContinuous,
          hasPhase: hasPhase,
          isPrecision: isPrecision
        ))
    else {
      return false
    }

    if isPrecision {
      return postPrecision(location: event.location, originalFlags: originalFlags, output: output)
    }
    return postSteps(location: event.location, flags: originalFlags, output: output)
  }

  private func postPrecision(
    location: CGPoint, originalFlags: CGEventFlags, output: ScrollRewriteOutput
  ) -> Bool {
    let flags = originalFlags.subtracting(.allOption)
    guard
      let replacement = synth.makeReplacement(
        location: location, flags: flags, linesX: output.linesX, linesY: output.linesY
      )
    else {
      return false
    }

    let optionKey: CGKeyCode =
      originalFlags.contains(.rightOption) ? CGKeyCode(kVK_RightOption) : CGKeyCode(kVK_Option)
    synth.makeFlagsChanged(flags: flags, keyCode: optionKey)?
      .post(tap: .cgSessionEventTap)
    replacement.post(tap: .cgSessionEventTap)
    synth.makeFlagsChanged(flags: originalFlags, keyCode: optionKey)?
      .post(tap: .cgSessionEventTap)
    return true
  }

  private func postSteps(
    location: CGPoint, flags: CGEventFlags, output: ScrollRewriteOutput
  ) -> Bool {
    guard
      let replacement = synth.makeReplacement(
        location: location, flags: flags, linesX: output.linesX, linesY: output.linesY
      )
    else { return false }
    replacement.post(tap: .cgSessionEventTap)
    return true
  }

  private func handleOtherMouse(type: CGEventType, event: CGEvent) -> Bool {
    guard configuration.isLookUpEnabled else { return false }
    guard event.getIntegerValueField(.mouseEventButtonNumber) == LookUpGesture.buttonNumber else {
      return false
    }
    if type == .otherMouseDown {
      LookUpGesture.post()
    }
    return true
  }

  private func notifyStatus() {
    onStatusChange?(Status(isInstalled: eventTap != nil, isEnabled: isEnabled && eventTap != nil))
  }
}
