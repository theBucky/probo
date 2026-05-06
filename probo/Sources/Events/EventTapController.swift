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

  private struct TapRuntime {
    var tap: CFMachPort?
    var runLoop: CFRunLoop?
    var isStopping = false
  }

  private struct State {
    var tapRuntime: TapRuntime?
    var isEnabled = false
    var status = Status(isInstalled: false, isEnabled: false)
    var configuration = AppConfiguration.defaultValue
  }

  private let scrollRewriter = ScrollEventRewriter(marker: EventTapController.synthMarker)
  private let state = Mutex(State())
  var onStatusChange: ((Status) -> Void)?

  @MainActor
  func apply(configuration: AppConfiguration) {
    state.withLock {
      $0.configuration = configuration
    }
  }

  @MainActor
  func setEnabled(_ enabled: Bool) {
    let action = state.withLock { state -> (shouldStart: Bool, tap: CFMachPort?) in
      let runtime = state.tapRuntime

      if state.isEnabled == enabled {
        return (enabled && runtime == nil, nil)
      }

      state.isEnabled = enabled
      if enabled {
        guard let runtime else { return (true, nil) }
        return (false, runtime.isStopping ? nil : runtime.tap)
      }
      return (false, runtime?.isStopping == false ? runtime?.tap : nil)
    }

    if action.shouldStart {
      startTapThread()
    }
    if let eventTap = action.tap {
      CGEvent.tapEnable(tap: eventTap, enable: enabled)
    }

    notifyStatus()
  }

  @MainActor
  func teardown() {
    let runtime = state.withLock { state in
      state.isEnabled = false
      state.tapRuntime?.isStopping = true
      return state.tapRuntime
    }

    if let eventTap = runtime?.tap, CFMachPortIsValid(eventTap) {
      CFMachPortInvalidate(eventTap)
    }
    if let tapRunLoop = runtime?.runLoop {
      CFRunLoopStop(tapRunLoop)
    }
    notifyStatus()
  }

  private func startTapThread() {
    let thread = Thread {
      self.runTapLoop()
    }
    thread.name = "Probo Event Tap"

    let shouldStart = state.withLock { state in
      guard state.tapRuntime == nil else { return false }
      state.tapRuntime = TapRuntime()
      return true
    }

    if shouldStart {
      thread.start()
    }
  }

  private func runTapLoop() {
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
      finishTapThread()
      notifyStatusOnMain()
      return
    }

    let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
    CFRunLoopAddSource(runLoop, source, .commonModes)
    defer {
      CFRunLoopRemoveSource(runLoop, source, .commonModes)
      if CFMachPortIsValid(tap) {
        CFMachPortInvalidate(tap)
      }
      finishTapThread()
      notifyStatusOnMain()
    }

    let action = state.withLock { state in
      guard var runtime = state.tapRuntime else {
        return (shouldStop: true, shouldEnable: false)
      }
      if runtime.isStopping {
        return (shouldStop: true, shouldEnable: false)
      }

      runtime.tap = tap
      runtime.runLoop = runLoop
      state.tapRuntime = runtime
      return (shouldStop: false, shouldEnable: state.isEnabled)
    }

    if action.shouldStop {
      return
    }

    CGEvent.tapEnable(tap: tap, enable: action.shouldEnable)
    notifyStatusOnMain()

    CFRunLoopRun()
  }

  private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
    let pass = Unmanaged.passUnretained(event)

    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
      let snapshot = runtimeSnapshot()
      if let eventTap = snapshot.eventTap, snapshot.isEnabled {
        CGEvent.tapEnable(tap: eventTap, enable: true)
      }
      return pass
    }

    let snapshot = runtimeSnapshot()
    guard snapshot.isEnabled else { return pass }

    switch type {
    case .otherMouseDown, .otherMouseUp:
      guard snapshot.configuration.isLookUpEnabled else { return pass }
      return LookUpGesture.consume(type: type, event: event) ? nil : pass
    case .scrollWheel:
      return scrollRewriter.rewrite(event: event, configuration: snapshot.configuration)
        ? nil : pass
    default:
      return pass
    }
  }

  private func runtimeSnapshot() -> (
    isEnabled: Bool, configuration: AppConfiguration, eventTap: CFMachPort?
  ) {
    state.withLock {
      let isStopping = $0.tapRuntime?.isStopping == true
      return ($0.isEnabled && !isStopping, $0.configuration, $0.tapRuntime?.tap)
    }
  }

  private func finishTapThread() {
    let shouldRestart = state.withLock {
      let shouldRestart = $0.tapRuntime?.isStopping == true && $0.isEnabled
      $0.tapRuntime = nil
      return shouldRestart
    }

    if shouldRestart {
      startTapThread()
    }
  }

  private func notifyStatusOnMain() {
    Task { @MainActor in
      notifyStatus()
    }
  }

  @MainActor
  private func notifyStatus() {
    let currentStatus = state.withLock { state -> Status? in
      let runtime = state.tapRuntime
      let isInstalled = runtime?.tap != nil && runtime?.isStopping == false
      let currentStatus = Status(
        isInstalled: isInstalled,
        isEnabled: state.isEnabled && isInstalled
      )
      if state.status == currentStatus {
        return nil
      }
      state.status = currentStatus
      return currentStatus
    }

    if let currentStatus {
      onStatusChange?(currentStatus)
    }
  }
}
