@preconcurrency import ApplicationServices
import Foundation
import Synchronization
import os

final class EventTapController: @unchecked Sendable {
  private struct TapState {
    var tap: CFMachPort?
    var installPending = false
    var isActive = false
    var lastEmittedEnabled = false
  }

  private enum InstallAction {
    case toggle(CFMachPort)
    case install
    case none
  }

  private let scrollRewriter: ScrollEventRewriter
  private let isActive = Atomic<Bool>(false)
  private let optionsRawValue = Atomic<UInt32>(
    EventTapOptions(configuration: .defaultValue).rawValue)
  // CFMachPort is installed off-main and toggled from both main and tap callbacks.
  private let tapState = OSAllocatedUnfairLock(uncheckedState: TapState())
  var onTapEnabledChange: (@MainActor (Bool) -> Void)?

  init(isTerminalFrontmost: @escaping @Sendable () -> Bool) {
    scrollRewriter = ScrollEventRewriter(isTerminalFrontmost: isTerminalFrontmost)
  }

  @MainActor
  func setConfiguration(_ configuration: AppConfiguration) {
    optionsRawValue.store(
      EventTapOptions(configuration: configuration).rawValue, ordering: .relaxed)
  }

  // Install once on first enable, then toggle forever via CGEvent.tapEnable.
  // The tap thread outlives setActive(false); process exit reaps it.
  // installPending coalesces back-to-back enables so the in-flight install thread
  // picks up the latest isActive at completion instead of spawning a duplicate tap.
  @MainActor
  func setActive(_ isActive: Bool) {
    self.isActive.store(isActive, ordering: .relaxed)
    let action = tapState.withLock { state -> InstallAction in
      let wasActive = state.isActive
      state.isActive = isActive
      if let tap = state.tap {
        return wasActive == isActive ? .none : .toggle(tap)
      }
      if !isActive || state.installPending { return .none }
      state.installPending = true
      return .install
    }
    switch action {
    case .toggle(let tap):
      CGEvent.tapEnable(tap: tap, enable: isActive)
      publishTapEnabledIfChanged()
    case .install:
      let thread = Thread { self.runTapLoop() }
      thread.name = "Probo Event Tap"
      thread.start()
    case .none:
      break
    }
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
      tapState.withLock { $0.installPending = false }
      publishTapEnabledOnMain()
      return
    }

    let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
    CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)

    let shouldEnable = tapState.withLock { state -> Bool in
      state.tap = tap
      state.installPending = false
      return state.isActive
    }
    CGEvent.tapEnable(tap: tap, enable: shouldEnable)
    publishTapEnabledOnMain()

    CFRunLoopRun()

    // CFRunLoopRun only returns if the tap source is invalidated externally
    // (e.g. event service restart); drop the dead port so a future setActive
    // retries the install instead of toggling a corpse.
    tapState.withLock { $0.tap = nil }
    publishTapEnabledOnMain()
  }

  private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
    let pass = Unmanaged.passUnretained(event)

    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
      let (isActive, tap) = tapState.withLock { ($0.isActive, $0.tap) }
      if let tap, isActive {
        CGEvent.tapEnable(tap: tap, enable: true)
      }
      return pass
    }

    // Skip self-synth re-entry before the lock so option-strip sandwiches don't
    // pay 3 lock acquisitions per click.
    if type == .scrollWheel,
      event.getIntegerValueField(.eventSourceUserData) == ScrollEventSynthesizer.marker
    {
      return pass
    }

    guard isActive.load(ordering: .relaxed) else { return pass }
    let options = EventTapOptions(rawValue: optionsRawValue.load(ordering: .relaxed))

    switch type {
    case .otherMouseDown, .otherMouseUp:
      guard options.isLookUpEnabled else { return pass }
      return LookUpGesture.consume(type: type, event: event) ? nil : pass
    case .scrollWheel:
      return scrollRewriter.rewrite(event: event, options: options) ? nil : pass
    default:
      return pass
    }
  }

  private func publishTapEnabledOnMain() {
    Task { @MainActor in publishTapEnabledIfChanged() }
  }

  @MainActor
  private func publishTapEnabledIfChanged() {
    let next = tapState.withLock { state -> Bool? in
      let next = state.isActive && state.tap != nil
      guard state.lastEmittedEnabled != next else { return nil }
      state.lastEmittedEnabled = next
      return next
    }
    if let next { onTapEnabledChange?(next) }
  }
}
