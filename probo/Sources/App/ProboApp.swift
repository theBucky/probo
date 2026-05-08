import AppKit
import Observation
import SwiftUI

@MainActor
@main
final class ProboApp: NSObject, NSApplicationDelegate {
  static func main() {
    let app = NSApplication.shared
    let delegate = ProboApp()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    app.run()
  }

  private let model = ProboModel()
  private var statusItem: NSStatusItem!
  private var statusMenu: ProboStatusMenu!
  private var settingsWindow: NSWindow?

  func applicationDidFinishLaunching(_ notification: Notification) {
    model.start()
    statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    statusMenu = ProboStatusMenu(model: model) { [weak self] in self?.openSettings() }
    statusItem.menu = statusMenu.menu
    refreshIcon()
  }

  // withObservationTracking is one-shot; re-enter on every change to keep tracking live.
  private func refreshIcon() {
    let symbolName = withObservationTracking {
      model.statusSymbolName
    } onChange: { [weak self] in
      Task { @MainActor in self?.refreshIcon() }
    }
    let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "Probo")
    image?.isTemplate = true
    statusItem.button?.image = image
  }

  private func openSettings() {
    if settingsWindow == nil {
      let controller = NSHostingController(rootView: ProboSettingsView(model: model))
      // SwiftUI Form has no intrinsic size until it lays out; preferredContentSize
      // pipes the layout result into the window so it doesn't open at 0x0.
      controller.sizingOptions = .preferredContentSize
      let window = NSWindow(contentViewController: controller)
      window.styleMask = [.titled, .closable]
      window.title = "Probo"
      window.isReleasedWhenClosed = false
      window.center()
      settingsWindow = window
    }
    NSApp.activate()
    settingsWindow?.makeKeyAndOrderFront(nil)
  }
}
