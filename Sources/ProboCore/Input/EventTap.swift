@preconcurrency import ApplicationServices
import Foundation
import Synchronization

final class EventTap: @unchecked Sendable {
  private struct TapState {
    var tap: CFMachPort?
    var installPending = false
  }

  private enum InstallAction {
    case toggle(CFMachPort)
    case install
    case none
  }

  private static let lookUpButtonNumber: Int64 = 3
  private static let lookUpKeyCode = CGKeyCode(0x02)

  private let scrollRewriter: ScrollRewriter
  private let lookUpKeys: (down: CGEvent, up: CGEvent)?
  private let isActive = Atomic<Bool>(false)
  private let isLookUpEnabled = Atomic<Bool>(InputConfiguration().isLookUpEnabled)
  private let scrollOptionsRawValue = Atomic<UInt32>(
    ScrollOptions(configuration: InputConfiguration()).rawValue)
  private let installedTapPointer = Atomic<UnsafeRawPointer?>(nil)
  private let tapState = Mutex(TapState())
  private let onEnabledChange: @MainActor (Bool) -> Void

  init(
    isTerminalFrontmost: @escaping @Sendable () -> Bool,
    onEnabledChange: @escaping @MainActor (Bool) -> Void
  ) {
    let lookUpKeyDown = CGEvent(
      keyboardEventSource: nil,
      virtualKey: Self.lookUpKeyCode,
      keyDown: true
    )
    let lookUpKeyUp = CGEvent(
      keyboardEventSource: nil,
      virtualKey: Self.lookUpKeyCode,
      keyDown: false
    )
    if let lookUpKeyDown, let lookUpKeyUp {
      lookUpKeyDown.flags = [.maskCommand, .maskControl]
      lookUpKeyUp.flags = [.maskCommand, .maskControl]
      lookUpKeys = (lookUpKeyDown, lookUpKeyUp)
    } else {
      lookUpKeys = nil
    }

    scrollRewriter = ScrollRewriter(isTerminalFrontmost: isTerminalFrontmost)
    self.onEnabledChange = onEnabledChange
  }

  @MainActor
  func setConfiguration(_ configuration: InputConfiguration) {
    isLookUpEnabled.store(configuration.isLookUpEnabled, ordering: .relaxed)
    scrollOptionsRawValue.store(
      ScrollOptions(configuration: configuration).rawValue,
      ordering: .relaxed
    )
  }

  // Install once on first enable, then toggle forever via CGEvent.tapEnable. The tap thread
  // outlives setActive(false); process exit reaps it. installPending coalesces back-to-back
  // enables so the in-flight install picks up the latest isActive instead of spawning a duplicate.
  @MainActor
  func setActive(_ active: Bool) {
    let wasActive = isActive.exchange(active, ordering: .relaxed)
    let action = tapState.withLock { state -> InstallAction in
      if let tap = state.tap {
        return wasActive == active ? .none : .toggle(tap)
      }
      guard active, !state.installPending else {
        return .none
      }
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
    let callback: CGEventTapCallBack = { proxy, type, event, userInfo in
      guard let userInfo else { return Unmanaged.passUnretained(event) }
      let eventTap = Unmanaged<EventTap>.fromOpaque(userInfo).takeUnretainedValue()
      return eventTap.handle(type: type, event: event, proxy: proxy)
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
    // The mutex owns the port; this unretained atomic view keeps callback recovery lock-free.
    installedTapPointer.store(Unmanaged.passUnretained(tap).toOpaque(), ordering: .relaxed)
    CGEvent.tapEnable(tap: tap, enable: isActive.load(ordering: .relaxed))
    publishTapEnabledOnMain()

    CFRunLoopRun()

    // CFRunLoopRun only returns if the tap source is invalidated externally
    // (e.g. event service restart); drop the dead port so a future setActive
    // reinstalls instead of toggling a corpse.
    installedTapPointer.store(nil, ordering: .relaxed)
    tapState.withLock { $0.tap = nil }
    publishTapEnabledOnMain()
  }

  private func handle(type: CGEventType, event: CGEvent, proxy: CGEventTapProxy)
    -> Unmanaged<CGEvent>?
  {
    let pass = Unmanaged.passUnretained(event)

    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
      if let pointer = installedTapPointer.load(ordering: .relaxed),
        isActive.load(ordering: .relaxed)
      {
        CGEvent.tapEnable(
          tap: Unmanaged<CFMachPort>.fromOpaque(pointer).takeUnretainedValue(),
          enable: true
        )
      }
      return pass
    }

    guard isActive.load(ordering: .relaxed) else { return pass }

    switch type {
    case .otherMouseDown, .otherMouseUp:
      guard
        isLookUpEnabled.load(ordering: .relaxed),
        event.getIntegerValueField(.mouseEventButtonNumber) == Self.lookUpButtonNumber
      else { return pass }
      if type == .otherMouseDown, let lookUpKeys {
        lookUpKeys.down.timestamp = event.timestamp
        lookUpKeys.up.timestamp = event.timestamp
        lookUpKeys.down.post(tap: .cgSessionEventTap)
        lookUpKeys.up.post(tap: .cgSessionEventTap)
      }
      return nil
    case .scrollWheel:
      return scrollRewriter.rewrite(
        event: event,
        options: ScrollOptions(
          rawValue: scrollOptionsRawValue.load(ordering: .relaxed)
        ),
        proxy: proxy
      ).map(Unmanaged.passUnretained)
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
    onEnabledChange(isActive.load(ordering: .relaxed) && installed)
  }
}
