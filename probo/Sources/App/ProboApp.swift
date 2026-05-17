import AppKit
import Observation
import SwiftUI

@MainActor
@main
final class ProboApp: NSObject, NSApplicationDelegate, NSWindowDelegate {
  static func main() {
    let app = NSApplication.shared
    let delegate = ProboApp()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    app.run()
  }

  private let runtime = ProboRuntime()
  private var statusItem: NSStatusItem!
  private var statusMenu: ProboStatusMenu!
  private var settingsWindow: NSWindow?
  private var lastSymbolName: String?

  func applicationDidFinishLaunching(_ notification: Notification) {
    statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    statusMenu = ProboStatusMenu(runtime: runtime) { [weak self] in
      self?.openSettings()
    }
    statusItem.menu = statusMenu.menu
    installMainMenu()
    runtime.start()
    observeStatusIcon()
  }

  // Accessory apps show no menu bar, but NSApp dispatches key equivalents
  // through the main menu regardless, so this is what wires up Cmd+W/Cmd+Q.
  private func installMainMenu() {
    let appMenu = NSMenu()
    appMenu.addItem(
      withTitle: "Quit Probo",
      action: #selector(NSApplication.terminate(_:)),
      keyEquivalent: "q")

    let windowMenu = NSMenu(title: "Window")
    windowMenu.addItem(
      withTitle: "Close",
      action: #selector(NSWindow.performClose(_:)),
      keyEquivalent: "w")

    let mainMenu = NSMenu()
    for submenu in [appMenu, windowMenu] {
      let item = NSMenuItem()
      mainMenu.addItem(item)
      mainMenu.setSubmenu(submenu, for: item)
    }
    NSApp.mainMenu = mainMenu
  }

  private func setStatusIcon(_ symbolName: String) {
    guard lastSymbolName != symbolName else { return }
    lastSymbolName = symbolName
    let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "Probo")
    image?.isTemplate = true
    statusItem.button?.image = image
  }

  private func observeStatusIcon() {
    withObservationTracking {
      setStatusIcon(runtime.statusSymbolName)
    } onChange: { [weak self] in
      Task { @MainActor in
        self?.observeStatusIcon()
      }
    }
  }

  private func openSettings() {
    runtime.refreshSystemState()
    if settingsWindow == nil {
      let controller = NSHostingController(
        rootView: ProboSettingsView(runtime: runtime))
      // SwiftUI Form has no intrinsic size until it lays out; preferredContentSize
      // pipes the layout result into the window so it doesn't open at 0x0.
      controller.sizingOptions = .preferredContentSize
      let window = NSWindow(contentViewController: controller)
      window.styleMask = [.titled, .closable]
      window.title = "Probo"
      window.isReleasedWhenClosed = false
      window.delegate = self
      window.center()
      settingsWindow = window
    }
    // An accessory app is a background utility; macOS only raises windows
    // reliably for apps that own a Dock icon. Promote to .regular while the
    // settings window is visible, then revert in windowWillClose.
    NSApp.setActivationPolicy(.regular)
    Task { @MainActor in
      // Let the policy change register before activating, otherwise the
      // activation lands before the app is a foreground citizen.
      try? await Task.sleep(for: .milliseconds(50))
      NSApp.activate()
      settingsWindow?.makeKeyAndOrderFront(nil)
      settingsWindow?.orderFrontRegardless()
    }
  }

  // Settings window closed: drop back to a menu-bar-only background app.
  func windowWillClose(_ notification: Notification) {
    NSApp.setActivationPolicy(.accessory)
  }
}
