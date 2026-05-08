import AppKit
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
  private let runtime = ProboRuntime()
  private var statusItem: NSStatusItem!
  private var statusMenu: ProboStatusMenu!
  private var settingsWindow: NSWindow?
  private var lastSymbolName: String?

  func applicationDidFinishLaunching(_ notification: Notification) {
    statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    statusMenu = ProboStatusMenu(model: model, runtime: runtime) { [weak self] in
      self?.openSettings()
    }
    statusItem.menu = statusMenu.menu
    runtime.onConfigurationChange = { [weak self, model] configuration in
      model.configuration = configuration
      self?.setStatusIcon(model.statusSymbolName)
    }
    runtime.onAccessibilityTrustChange = { [weak self, model] trusted in
      model.accessibilityTrusted = trusted
      self?.setStatusIcon(model.statusSymbolName)
    }
    runtime.onTapStatusChange = { [weak self, model] status in
      model.tapStatus = status
      self?.setStatusIcon(model.statusSymbolName)
    }
    runtime.onStartAtLoginChange = { [model] enabled in
      model.startAtLoginEnabled = enabled
    }
    runtime.start()
  }

  private func setStatusIcon(_ symbolName: String) {
    guard lastSymbolName != symbolName else { return }
    lastSymbolName = symbolName
    let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "Probo")
    image?.isTemplate = true
    statusItem.button?.image = image
  }

  private func openSettings() {
    runtime.refreshExternalState()
    if settingsWindow == nil {
      let controller = NSHostingController(
        rootView: ProboSettingsView(model: model, runtime: runtime))
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
