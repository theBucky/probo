import AppKit

@MainActor
package final class ProboStatusMenu: NSObject, NSMenuDelegate {
  private let runtime: ProboRuntime
  private let onOpenSettings: () -> Void
  package let menu = NSMenu()

  package init(runtime: ProboRuntime, onOpenSettings: @escaping () -> Void) {
    self.runtime = runtime
    self.onOpenSettings = onOpenSettings
    super.init()
    menu.autoenablesItems = false
    menu.delegate = self
  }

  // Rebuild on open so toggle states track the runtime without per-item observation plumbing.
  package func menuNeedsUpdate(_ menu: NSMenu) {
    runtime.refreshSystemState()
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
    state: Bool = false
  ) -> NSMenuItem {
    let item = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
    item.target = self
    item.state = state ? .on : .off
    return item
  }

  @objc private func toggleEnabled() {
    runtime.isEnabled.toggle()
  }

  @objc private func requestAccess() {
    runtime.requestAccessibilityAccess()
  }

  @objc private func showSettings() {
    onOpenSettings()
  }

  @objc private func toggleStartAtLogin() {
    runtime.setStartAtLoginEnabled(!runtime.startAtLoginEnabled)
  }

  @objc private func quit() {
    NSApp.terminate(nil)
  }
}
