import AppKit
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

  private let runtime = ProboRuntime(environment: .live())
  private var statusItem: NSStatusItem!
  private var settingsWindow: NSWindow?
  private var lastAccessibilityTrusted: Bool?

  func applicationDidFinishLaunching(_ _: Notification) {
    statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    statusItem.menu = NSMenu()
    statusItem.menu?.autoenablesItems = false
    statusItem.menu?.delegate = self
    installMainMenu()
    runtime.onChange = { [weak self] in
      guard let self else { return }
      setStatusIcon(runtime.statusSymbolName)
      reloadSettingsIfAccessibilityChanged()
    }
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

  private func setStatusIcon(_ symbolName: String) {
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

    let accessItem = item(
      title: "Accessibility Access",
      action: #selector(requestAccess),
      state: runtime.accessibilityTrusted
    )
    accessItem.isEnabled = !runtime.accessibilityTrusted
    menu.addItem(accessItem)
    menu.addItem(item(title: "Settings...", action: #selector(showSettings)))

    menu.addItem(.separator())

    menu.addItem(item(title: "Quit Probo", action: #selector(quit), keyEquivalent: "q"))
  }

  private func item(
    title: String,
    action: Selector,
    keyEquivalent: String = "",
    state: Bool? = nil
  ) -> NSMenuItem {
    let item = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
    item.target = self
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
    openSettings()
  }

  @objc private func toggleStartAtLogin() {
    runtime.setStartAtLoginEnabled(!runtime.startAtLoginEnabled)
  }

  @objc private func quit() {
    NSApp.terminate(nil)
  }

  private func openSettings() {
    runtime.refreshAccessibility()
    // Status-item apps start as accessory apps. Promote before creating/showing
    // the settings window so AppKit orders it like a normal foreground window.
    NSApp.setActivationPolicy(.regular)

    let window = settingsWindow ?? makeSettingsWindow()
    NSApp.activate(ignoringOtherApps: true)
    window.makeKeyAndOrderFront(nil)
  }

  private func reloadSettingsIfAccessibilityChanged() {
    let accessibilityTrusted = runtime.accessibilityTrusted
    guard lastAccessibilityTrusted != accessibilityTrusted else { return }
    lastAccessibilityTrusted = accessibilityTrusted
    (settingsWindow?.contentViewController as? ProboSettingsViewController)?.reload()
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
