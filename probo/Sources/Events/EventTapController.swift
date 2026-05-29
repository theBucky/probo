@preconcurrency import ApplicationServices
import Foundation
import Synchronization
import os

final class EventTapController: @unchecked Sendable {
  private struct TapState {
    var tap: CFMachPort?
    var installPending = false
  }

  private enum InstallAction {
    case toggle(CFMachPort)
    case install
    case none
  }

  private let scrollRewriter: ScrollEventRewriter
  // Atomic, not lock-guarded, because the hot path reads it on every event.
  private let isActive = Atomic<Bool>(false)
  private let optionsRawValue = Atomic<UInt32>(
    EventTapOptions(configuration: .defaultValue).rawValue)
  private let tapState = Mutex(TapState())
  var onTapEnabledChange: (@MainActor (Bool) -> Void)?

  init(isTerminalFrontmost: @escaping @Sendable () -> Bool) {
    scrollRewriter = ScrollEventRewriter(isTerminalFrontmost: isTerminalFrontmost)
  }

  @MainActor
  func setConfiguration(_ configuration: AppConfiguration) {
    optionsRawValue.store(
      EventTapOptions(configuration: configuration).rawValue, ordering: .relaxed)
  }

  // Install once on first enable, then toggle forever via CGEvent.tapEnable. The tap thread
  // outlives setActive(false); process exit reaps it. installPending coalesces back-to-back
  // enables so the in-flight install picks up the latest isActive instead of spawning a duplicate.
  @MainActor
  func setActive(_ active: Bool) {
    let wasActive = isActive.exchange(active, ordering: .relaxed)
    let action = tapState.withLock { state -> InstallAction in
      if let tap = state.tap { return wasActive == active ? .none : .toggle(tap) }
      if !active || state.installPending { return .none }
      state.installPending = true
      return .install
    }
    switch action {
    case .toggle(let tap):
      CGEvent.tapEnable(tap: tap, enable: active)
      publishTapEnabled()
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
    tapState.withLock {
      $0.tap = tap
      $0.installPending = false
    }
    CGEvent.tapEnable(tap: tap, enable: isActive.load(ordering: .relaxed))
    publishTapEnabledOnMain()

    CFRunLoopRun()

    // CFRunLoopRun only returns if the tap source is invalidated externally
    // (e.g. event service restart); drop the dead port so a future setActive
    // reinstalls instead of toggling a corpse.
    tapState.withLock { $0.tap = nil }
    publishTapEnabledOnMain()
  }

  private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
    let pass = Unmanaged.passUnretained(event)

    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
      let tap = tapState.withLock { $0.tap }
      if let tap, isActive.load(ordering: .relaxed) {
        CGEvent.tapEnable(tap: tap, enable: true)
      }
      return pass
    }

    // Bail on our own synthesized events first so the option-strip sandwich
    // doesn't re-enter the rewriter three times per click.
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
      return scrollRewriter.rewrite(event: event, options: options).map(Unmanaged.passUnretained)
    default:
      return pass
    }
  }

  private func publishTapEnabledOnMain() {
    Task { @MainActor in publishTapEnabled() }
  }

  @MainActor
  private func publishTapEnabled() {
    let installed = tapState.withLock { $0.tap != nil }
    onTapEnabledChange?(isActive.load(ordering: .relaxed) && installed)
  }
}
