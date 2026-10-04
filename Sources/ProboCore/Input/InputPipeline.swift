import AppKit
@preconcurrency import ApplicationServices
import Observation
import Synchronization

// Owns the session event tap. Main-actor members publish state through atomics; the nonisolated callback reads them without locks.
@MainActor
@Observable
final class InputPipeline {
  private(set) var isRunning = false

  @ObservationIgnored private var tap: CFMachPort?
  @ObservationIgnored private var terminalFocusTask: Task<Void, Never>?

  private let isActive = Atomic<Bool>(false)
  private let configuration = Atomic<InputConfiguration>(InputConfiguration())
  private let isTerminalFrontmost = Atomic<Bool>(false)
  private nonisolated(unsafe) let scrollRewriter = ScrollRewriter()
  private nonisolated(unsafe) let lookUp = LookUpShortcut()

  func apply(_ configuration: InputConfiguration, isEnabled: Bool) {
    self.configuration.store(configuration, ordering: .relaxed)
    setTerminalFocusMonitoring(isEnabled && configuration.isTerminalOptimizationEnabled)
    setTapActive(isEnabled)
  }

  // MARK: Terminal focus

  // Frontmost app is a deliberate approximation: macOS routes scroll events to the window under the pointer, but resolving that target would add a lookup to every notch.
  private static let terminalBundleIDs: Set<String> = [
    "com.apple.Terminal",
    "com.mitchellh.ghostty",
    "dev.warp.Warp-Stable",
    "net.kovidgoyal.kitty",
    "com.github.wez.wezterm",
    "org.alacritty",
    "co.zeit.hyper",
    "org.tabby",
    "com.raphamorim.rio",
  ]

  private func setTerminalFocusMonitoring(_ enabled: Bool) {
    guard enabled else {
      terminalFocusTask?.cancel()
      terminalFocusTask = nil
      isTerminalFrontmost.store(false, ordering: .relaxed)
      return
    }
    guard terminalFocusTask == nil else { return }
    refreshTerminalFocus()
    terminalFocusTask = Task { [weak self] in
      for await _ in NSWorkspace.shared.notificationCenter.notifications(
        named: NSWorkspace.didActivateApplicationNotification
      ) {
        guard let self else { return }
        refreshTerminalFocus()
      }
    }
  }

  private func refreshTerminalFocus() {
    let bundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
    isTerminalFrontmost.store(
      bundleID.map(Self.terminalBundleIDs.contains) ?? false,
      ordering: .relaxed
    )
  }

  // MARK: Tap lifecycle

  // Installs once on first enable, then toggles via tapEnable; the tap thread lives until process exit. Installation needs Accessibility trust, so a failed install leaves `tap` nil and the next enable retries.
  private func setTapActive(_ active: Bool) {
    isActive.store(active, ordering: .relaxed)
    if tap == nil, active {
      tap = installTap()
    }
    guard let tap else {
      isRunning = false
      return
    }
    CGEvent.tapEnable(tap: tap, enable: active)
    isRunning = active
  }

  private func installTap() -> CFMachPort? {
    let mask =
      CGEventMask(1 << CGEventType.scrollWheel.rawValue)
      | CGEventMask(1 << CGEventType.otherMouseDown.rawValue)
      | CGEventMask(1 << CGEventType.otherMouseUp.rawValue)
    let callback: CGEventTapCallBack = { proxy, type, event, userInfo in
      guard let userInfo else { return Unmanaged.passUnretained(event) }
      let pipeline = Unmanaged<InputPipeline>.fromOpaque(userInfo).takeUnretainedValue()
      return pipeline.handle(type: type, event: event, proxy: proxy)
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
    else { return nil }

    nonisolated(unsafe) let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
    let thread = Thread { [self] in
      CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
      CFRunLoopRun()
      // Returns only when the port is invalidated externally, e.g. an event service restart.
      Task { @MainActor in
        self.tap = nil
        self.isRunning = false
      }
    }
    thread.name = "Probo Event Tap"
    thread.start()
    return tap
  }

  // MARK: Callback thread

  private nonisolated func handle(
    type: CGEventType,
    event: CGEvent,
    proxy: CGEventTapProxy
  ) -> Unmanaged<CGEvent>? {
    let pass = Unmanaged.passUnretained(event)

    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
      // Rare and never a notch, so a hop to the port's owner is affordable here.
      Task { @MainActor in
        if let tap, isActive.load(ordering: .relaxed) {
          CGEvent.tapEnable(tap: tap, enable: true)
        }
      }
      return pass
    }

    guard isActive.load(ordering: .relaxed) else { return pass }
    let configuration = configuration.load(ordering: .relaxed)
    switch type {
    case .scrollWheel:
      switch scrollRewriter.rewrite(
        event,
        configuration: configuration,
        isTerminalFrontmost: isTerminalFrontmost.load(ordering: .relaxed)
      ) {
      case .deliver: return pass
      case .drop: return nil
      case .post(let stripped):
        stripped.post(via: proxy)
        return nil
      }
    case .otherMouseDown, .otherMouseUp:
      guard
        configuration.isLookUpEnabled,
        event.getIntegerValueField(.mouseEventButtonNumber) == LookUpShortcut.buttonNumber
      else { return pass }
      if type == .otherMouseDown {
        lookUp?.post(timestamp: event.timestamp)
      }
      return nil
    default:
      return pass
    }
  }
}

// Mouse button 4 becomes Control-Command-D, the system Look Up shortcut.
private struct LookUpShortcut {
  static let buttonNumber: Int64 = 3
  private static let keyCode = CGKeyCode(0x02)

  private let keyDown: CGEvent
  private let keyUp: CGEvent

  init?() {
    guard
      let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: Self.keyCode, keyDown: true),
      let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: Self.keyCode, keyDown: false)
    else { return nil }
    keyDown.flags = [.maskCommand, .maskControl]
    keyUp.flags = [.maskCommand, .maskControl]
    self.keyDown = keyDown
    self.keyUp = keyUp
  }

  func post(timestamp: CGEventTimestamp) {
    keyDown.timestamp = timestamp
    keyUp.timestamp = timestamp
    keyDown.post(tap: .cgSessionEventTap)
    keyUp.post(tap: .cgSessionEventTap)
  }
}
