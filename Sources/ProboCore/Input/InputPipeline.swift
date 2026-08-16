import AppKit
import Synchronization

@MainActor
final class InputPipeline {
  private let terminalFocus: TerminalFocusMonitor
  private let eventTap: EventTap

  init(onRunningChange: @escaping @MainActor (Bool) -> Void) {
    let terminalFocus = TerminalFocusMonitor()
    self.terminalFocus = terminalFocus
    eventTap = EventTap(
      isTerminalFrontmost: { terminalFocus.isTerminalFrontmost() },
      onEnabledChange: onRunningChange
    )
  }

  func apply(_ configuration: InputConfiguration, isEnabled: Bool) {
    terminalFocus.setActive(isEnabled && configuration.isTerminalOptimizationEnabled)
    eventTap.setConfiguration(configuration)
    eventTap.setActive(isEnabled)
  }
}

// Frontmost focus is a deliberate hot-path approximation. macOS routes scroll events to the
// window under the pointer, but resolving that target would add a lookup or lock to every notch.
// Terminal interaction normally implies focus, so one atomic read covers the useful cases.
@MainActor
private final class TerminalFocusMonitor {
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

  private nonisolated let terminalFrontmost = Atomic<Bool>(false)
  private var activationTask: Task<Void, Never>?

  nonisolated func isTerminalFrontmost() -> Bool {
    terminalFrontmost.load(ordering: .relaxed)
  }

  func setActive(_ isActive: Bool) {
    if !isActive {
      activationTask?.cancel()
      activationTask = nil
      terminalFrontmost.store(false, ordering: .relaxed)
      return
    }

    guard activationTask == nil else { return }
    refresh()
    activationTask = Task { [weak self] in
      for await _ in NSWorkspace.shared.notificationCenter.notifications(
        named: NSWorkspace.didActivateApplicationNotification
      ) {
        guard let self else { return }
        refresh()
      }
    }
  }

  private func refresh() {
    terminalFrontmost.store(
      NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        .map(Self.terminalBundleIDs.contains) ?? false,
      ordering: .relaxed
    )
  }
}
