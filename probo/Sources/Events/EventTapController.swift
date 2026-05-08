@preconcurrency import ApplicationServices
import Foundation
import Synchronization

final class EventTapController: @unchecked Sendable {
  // ASCII "PROBO" — tags synthesized events so the tap can skip its own output.
  private static let synthMarker: Int64 = 0x50_524F_424F

  struct Status: Equatable, Sendable {
    var isInstalled: Bool
    var isEnabled: Bool
  }

  // Non-nil runtime with nil tap signals a thread mid-startup. id pins
  // ownership so a stale thread cannot clobber a newer runtime.
  private struct TapRuntime {
    let id: UInt64
    var tap: CFMachPort?
    var runLoop: CFRunLoop?
  }

  private struct State {
    var tapRuntime: TapRuntime?
    var nextTapId: UInt64 = 0
    var isEnabled = false
    var status = Status(isInstalled: false, isEnabled: false)
    var configuration = AppConfiguration.defaultValue
  }

  private enum Action {
    case startThread(id: UInt64)
    case toggle(CFMachPort)
  }

  private let scrollRewriter: ScrollEventRewriter
  private let state = Mutex(State())
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

  @MainActor
  func setEnabled(_ enabled: Bool) {
    // Reserve the slot so a concurrent setEnabled coalesces into the toggle path.
    let action = state.withLock { state -> Action? in
      state.isEnabled = enabled
      if enabled, state.tapRuntime == nil {
        state.nextTapId += 1
        let id = state.nextTapId
        state.tapRuntime = TapRuntime(id: id)
        return .startThread(id: id)
      }
      if let tap = state.tapRuntime?.tap {
        return .toggle(tap)
      }
      return nil
    }

    switch action {
    case .startThread(let id):
      let thread = Thread { self.runTapLoop(id: id) }
      thread.name = "Probo Event Tap"
      thread.start()
    case .toggle(let tap):
      CGEvent.tapEnable(tap: tap, enable: enabled)
    case nil:
      break
    }
    notifyStatus()
  }

  @MainActor
  func teardown() {
    let runtime = state.withLock { state -> TapRuntime? in
      state.isEnabled = false
      let runtime = state.tapRuntime
      state.tapRuntime = nil
      return runtime
    }

    if let tap = runtime?.tap {
      CFMachPortInvalidate(tap)
    }
    if let runLoop = runtime?.runLoop {
      CFRunLoopStop(runLoop)
    }
    notifyStatus()
  }

  private func runTapLoop(id: UInt64) {
    let runLoop = CFRunLoopGetCurrent()
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
      // Drop the placeholder so a subsequent setEnabled retries the install.
      clearOwnedRuntime(id: id)
      notifyStatusOnMain()
      return
    }

    let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
    CFRunLoopAddSource(runLoop, source, .commonModes)
    defer {
      CFRunLoopRemoveSource(runLoop, source, .commonModes)
      // CFMachPortInvalidate is idempotent (guarded by the port's _state).
      CFMachPortInvalidate(tap)
      clearOwnedRuntime(id: id)
      notifyStatusOnMain()
    }

    // teardown may have run between tapCreate and now; bail so defer cleans up.
    let shouldEnable = state.withLock { state -> Bool? in
      guard state.tapRuntime?.id == id else { return nil }
      state.tapRuntime = TapRuntime(id: id, tap: tap, runLoop: runLoop)
      return state.isEnabled
    }
    guard let shouldEnable else { return }

    CGEvent.tapEnable(tap: tap, enable: shouldEnable)
    notifyStatusOnMain()

    CFRunLoopRun()
  }

  private func clearOwnedRuntime(id: UInt64) {
    state.withLock { state in
      if state.tapRuntime?.id == id { state.tapRuntime = nil }
    }
  }

  private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
    let pass = Unmanaged.passUnretained(event)

    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
      let (isEnabled, tap) = state.withLock { ($0.isEnabled, $0.tapRuntime?.tap) }
      if let tap, isEnabled {
        CGEvent.tapEnable(tap: tap, enable: true)
      }
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
      let isInstalled = state.tapRuntime?.tap != nil
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
