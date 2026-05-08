@preconcurrency import ApplicationServices
import Foundation
import os

final class EventTapController: @unchecked Sendable {
  // ASCII "PROBO" — tags synthesized events so the tap can skip its own output.
  private static let synthMarker: Int64 = 0x50_524F_424F

  struct Status: Equatable, Sendable {
    var isInstalled: Bool
    var isEnabled: Bool
  }

  private struct State {
    var tap: CFMachPort?
    var installPending = false
    var isEnabled = false
    var status = Status(isInstalled: false, isEnabled: false)
    var configuration = AppConfiguration.defaultValue
  }

  private enum InstallAction {
    case toggle(CFMachPort)
    case install
    case none
  }

  private let scrollRewriter: ScrollEventRewriter
  // ~5x faster than Synchronization.Mutex on this hot path; uncheckedState
  // because CFMachPort? blocks Sendable conformance.
  private let state = OSAllocatedUnfairLock(uncheckedState: State())
  var onStatusChange: ((Status) -> Void)?

  init(isTerminalFrontmost: @escaping @Sendable () -> Bool) {
    scrollRewriter = ScrollEventRewriter(
      marker: Self.synthMarker,
      isTerminalFrontmost: isTerminalFrontmost
    )
  }

  @MainActor
  func apply(configuration: AppConfiguration) {
    state.withLock { $0.configuration = configuration }
  }

  // Install once on first enable, then toggle forever via CGEvent.tapEnable.
  // The tap thread outlives setEnabled(false); process exit reaps it.
  // installPending coalesces back-to-back enables so the in-flight install thread
  // picks up the latest isEnabled at completion instead of spawning a duplicate tap.
  @MainActor
  func setEnabled(_ enabled: Bool) {
    let action = state.withLock { state -> InstallAction in
      state.isEnabled = enabled
      if let tap = state.tap { return .toggle(tap) }
      if !enabled || state.installPending { return .none }
      state.installPending = true
      return .install
    }
    switch action {
    case .toggle(let tap):
      CGEvent.tapEnable(tap: tap, enable: enabled)
    case .install:
      let thread = Thread { self.runTapLoop() }
      thread.name = "Probo Event Tap"
      thread.start()
    case .none:
      break
    }
    notifyStatus()
  }

  private func runTapLoop() {
    let mask =
      CGEventMask(1 << CGEventType.scrollWheel.rawValue)
      | CGEventMask(1 << CGEventType.otherMouseDown.rawValue)
      | CGEventMask(1 << CGEventType.otherMouseUp.rawValue)
    let callback: CGEventTapCallBack = { _, type, event, userInfo in
      guard let userInfo else { return Unmanaged.passUnretained(event) }
      let controller = Unmanaged<EventTapController>.fromOpaque(userInfo).takeUnretainedValue()
      return controller.handle(type: type, event: event)
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
      state.withLock { $0.installPending = false }
      notifyStatusOnMain()
      return
    }

    let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
    CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)

    let shouldEnable = state.withLock { state -> Bool in
      state.tap = tap
      state.installPending = false
      return state.isEnabled
    }
    CGEvent.tapEnable(tap: tap, enable: shouldEnable)
    notifyStatusOnMain()

    CFRunLoopRun()

    // CFRunLoopRun only returns if the tap source is invalidated externally
    // (e.g. event service restart); drop the dead port so a future setEnabled
    // retries the install instead of toggling a corpse.
    state.withLock { $0.tap = nil }
    notifyStatusOnMain()
  }

  private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
    let pass = Unmanaged.passUnretained(event)

    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
      let (isEnabled, tap) = state.withLock { ($0.isEnabled, $0.tap) }
      if let tap, isEnabled {
        CGEvent.tapEnable(tap: tap, enable: true)
      }
      return pass
    }

    // Skip self-synth re-entry before the lock so option-strip sandwiches don't
    // pay 3 lock acquisitions per click.
    if type == .scrollWheel,
      event.getIntegerValueField(.eventSourceUserData) == Self.synthMarker
    {
      return pass
    }

    let (isEnabled, configuration) = state.withLock { ($0.isEnabled, $0.configuration) }
    guard isEnabled else { return pass }

    switch type {
    case .otherMouseDown, .otherMouseUp:
      guard configuration.isLookUpEnabled else { return pass }
      return LookUpGesture.consume(type: type, event: event) ? nil : pass
    case .scrollWheel:
      return scrollRewriter.rewrite(event: event, configuration: configuration) ? nil : pass
    default:
      return pass
    }
  }

  private func notifyStatusOnMain() {
    Task { @MainActor in notifyStatus() }
  }

  @MainActor
  private func notifyStatus() {
    let next = state.withLock { state -> Status? in
      let isInstalled = state.tap != nil
      let next = Status(
        isInstalled: isInstalled,
        isEnabled: state.isEnabled && isInstalled
      )
      guard state.status != next else { return nil }
      state.status = next
      return next
    }
    if let next { onStatusChange?(next) }
  }
}
