import AppKit
import Synchronization

// Built-in terminal heuristic. Watches NSWorkspace on the main actor and exposes a
// nonisolated boolean so the event tap can read it from its dedicated thread without locking.
//
// Trade-off: keys off the frontmost app rather than the wheel event's target window. macOS
// routes scroll events to the window under the cursor, so a background terminal window is
// missed and a non-terminal background window under a focused terminal is mistakenly treated
// as terminal-bound. Resolving the target requires either a per-event NSRunningApplication
// lookup or a mutex-guarded PID set on the hot path; both violate the allocation-free
// invariant. TUI/REPL interaction always implies focus, so frontmost is the right heuristic
// for the cases this feature actually targets.
@MainActor
final class FrontmostAppMonitor {
  private static let terminalBundleIDs: Set<String> = [
    "com.apple.Terminal",
    "com.googlecode.iterm2",
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

  nonisolated func isTerminalFrontmost() -> Bool {
    terminalFrontmost.load(ordering: .relaxed)
  }

  func start() {
    refresh()
    let stream = NSWorkspace.shared.notificationCenter
      .notifications(named: NSWorkspace.didActivateApplicationNotification)
    Task { [weak self] in
      for await _ in stream {
        guard let self else { return }
        refresh()
      }
    }
  }

  private func refresh() {
    let bundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
    let isTerminal = bundleID.map(Self.terminalBundleIDs.contains) ?? false
    terminalFrontmost.store(isTerminal, ordering: .relaxed)
  }
}
