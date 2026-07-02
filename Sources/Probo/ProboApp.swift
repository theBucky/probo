import AppKit
import Observation
import ProboCore

@MainActor
@main
final class ProboApp: NSObject, NSApplicationDelegate, NSWindowDelegate, NSMenuDelegate {
  static func main() {
    let app = NSApplication.shared
    let delegate = ProboApp()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    app.run()
  }

  private let runtime = Runtime()
  private var statusItem: NSStatusItem!
  private var settingsWindow: NSWindow?

  func applicationDidFinishLaunching(_ _: Notification) {
    statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    let menu = NSMenu()
    menu.autoenablesItems = false
    menu.delegate = self
    statusItem.menu = menu
    installMainMenu()
    trackStatusIcon()
    runtime.refreshAccessibility()
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

  private func trackStatusIcon() {
    withObservationTracking {
      setStatusIcon(runtime.status)
    } onChange: { [weak self] in
      Task { @MainActor in self?.trackStatusIcon() }
    }
  }

  private func setStatusIcon(_ status: RuntimeStatus) {
    let symbolName =
      switch status {
      case .needsAccessibility: "exclamationmark.triangle.fill"
      case .active: "computermouse.fill"
      case .idle: "computermouse"
      }
    let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "Probo")
    image?.isTemplate = true
    statusItem.button?.image = image
  }

  // Rebuild on open so toggle states track the runtime without per-item observation plumbing.
  func menuNeedsUpdate(_ menu: NSMenu) {
    runtime.refreshAccessibility()
    menu.removeAllItems()

    menu.addItem(
      item(
        title: "Enabled",
        action: #selector(toggleEnabled),
        state: runtime.isEnabled
      ))
    menu.addItem(
      item(
        title: "Start at Login",
        action: #selector(toggleStartAtLogin),
        state: runtime.startAtLoginEnabled
      ))

    menu.addItem(.separator())

    menu.addItem(
      item(
        title: "Accessibility Access",
        action: #selector(requestAccess),
        isEnabled: !runtime.accessibilityTrusted,
        state: runtime.accessibilityTrusted
      ))
    menu.addItem(item(title: "Settings...", action: #selector(showSettings)))

    menu.addItem(.separator())

    menu.addItem(item(title: "Quit Probo", action: #selector(quit), keyEquivalent: "q"))
  }

  private func item(
    title: String,
    action: Selector,
    keyEquivalent: String = "",
    isEnabled: Bool = true,
    state: Bool? = nil
  ) -> NSMenuItem {
    let item = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
    item.target = self
    item.isEnabled = isEnabled
    if let state {
      item.state = state ? .on : .off
    }
    return item
  }

  @objc private func toggleEnabled() {
    runtime.isEnabled.toggle()
  }

  @objc private func requestAccess() {
    runtime.requestAccessibilityAccess()
  }

  @objc private func showSettings() {
    runtime.refreshAccessibility()
    // Status-item apps start as accessory apps. Promote before creating/showing
    // the settings window so AppKit orders it like a normal foreground window.
    NSApp.setActivationPolicy(.regular)

    let window = settingsWindow ?? makeSettingsWindow()
    NSApp.activate(ignoringOtherApps: true)
    window.makeKeyAndOrderFront(nil)
  }

  @objc private func toggleStartAtLogin() {
    runtime.setStartAtLoginEnabled(!runtime.startAtLoginEnabled)
  }

  @objc private func quit() {
    NSApp.terminate(nil)
  }

  private func makeSettingsWindow() -> NSWindow {
    let controller = ProboSettingsViewController(runtime: runtime)
    let window = NSWindow(contentViewController: controller)
    window.styleMask = [.titled, .closable]
    window.title = "Probo"
    window.isReleasedWhenClosed = false
    window.setContentSize(controller.preferredContentSize)
    window.delegate = self
    window.center()
    settingsWindow = window
    return window
  }

  // Settings window closed: drop back to a menu-bar-only background app.
  func windowWillClose(_ _: Notification) {
    NSApp.setActivationPolicy(.accessory)
  }
}
