import AppKit

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

  private let runtime = ProboRuntime(environment: .live())
  private var statusItem: NSStatusItem!
  private var statusMenu: ProboStatusMenu!
  private var settingsWindow: NSWindow?
  private var lastSymbolName: String?
  private var lastAccessibilityTrusted: Bool?

  func applicationDidFinishLaunching(_ _: Notification) {
    statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    statusMenu = ProboStatusMenu(runtime: runtime) { [weak self] in
      self?.openSettings()
    }
    statusItem.menu = statusMenu.menu
    installMainMenu()
    runtime.onChange = { [weak self] in
      guard let self else { return }
      setStatusIcon(runtime.statusSymbolName)
      reloadSettingsIfAccessibilityChanged()
    }
    runtime.start()
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

  private func openSettings() {
    runtime.refreshSystemState()
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
