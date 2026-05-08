import AppKit

@MainActor
final class ProboStatusMenu: NSObject, NSMenuDelegate {
  private let model: ProboModel
  private let onOpenSettings: () -> Void
  let menu = NSMenu()

  init(model: ProboModel, onOpenSettings: @escaping () -> Void) {
    self.model = model
    self.onOpenSettings = onOpenSettings
    super.init()
    menu.autoenablesItems = false
    menu.delegate = self
  }

  // Rebuild on open so toggle states and the access-required item track current model state
  // without per-item observation plumbing. Sections group by state-shape so macOS 26's
  // per-section checkmark column reservation produces consistent leading insets.
  func menuNeedsUpdate(_ menu: NSMenu) {
    model.refreshLaunchAtLogin()
    menu.removeAllItems()

    menu.addItem(
      item(
        title: "Enabled",
        action: #selector(toggleEnabled),
        state: model.configuration.isEnabled
      ))
    menu.addItem(
      item(
        title: "Start at Login",
        action: #selector(toggleStartAtLogin),
        state: model.startAtLoginEnabled
      ))

    menu.addItem(.separator())

    if !model.accessibilityTrusted {
      menu.addItem(item(title: "Request Accessibility Access...", action: #selector(requestAccess)))
    }
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
    model.setEnabled(!model.configuration.isEnabled)
  }

  @objc private func requestAccess() {
    model.requestAccessibilityAccess()
  }

  @objc private func showSettings() {
    onOpenSettings()
  }

  @objc private func toggleStartAtLogin() {
    model.setStartAtLoginEnabled(!model.startAtLoginEnabled)
  }

  @objc private func quit() {
    model.quit()
  }
}
