import AppKit

@main
enum ProboApp {
  @MainActor
  static func main() {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.setActivationPolicy(.accessory)
    app.delegate = delegate
    app.run()
  }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  private let configurationStore = AppConfigurationStore()
  private let launchAtLoginManager = LaunchAtLoginManager()
  private let eventTapController = EventTapController()
  private let statusMenuController = StatusMenuController()

  private var configuration = AppConfiguration(isEnabled: true, intensity: .slow)
  private var tapStatus = EventTapController.Status(isInstalled: false, isEnabled: false)
  private var accessibilityTrusted = false
  private var lastMenuState: StatusMenuState?
  private var permissionMonitor: Task<Void, Never>?

  func applicationDidFinishLaunching(_ notification: Notification) {
    configuration = configurationStore.load()
    eventTapController.intensity = configuration.intensity

    eventTapController.onStatusChange = { [weak self] status in
      guard let self else { return }
      tapStatus = status
      renderStatusMenu()
    }

    statusMenuController.onToggleEnabled = { [weak self] in self?.toggleEnabled() }
    statusMenuController.onSelectIntensity = { [weak self] in self?.selectIntensity($0) }
    statusMenuController.onToggleStartAtLogin = { [weak self] in self?.toggleStartAtLogin() }
    statusMenuController.onGrantAccessibilityAccess = { [weak self] in
      self?.requestAccessibilityAccess()
    }
    statusMenuController.onQuit = { NSApplication.shared.terminate(nil) }

    accessibilityTrusted = AccessibilityPermission.isTrusted(prompt: configuration.isEnabled)
    refreshRuntime()
    startPermissionMonitor()
  }

  func applicationWillTerminate(_ notification: Notification) {
    permissionMonitor?.cancel()
    eventTapController.teardown()
  }

  private func toggleEnabled() {
    configuration.isEnabled.toggle()
    configurationStore.save(configuration)
    if configuration.isEnabled {
      accessibilityTrusted = AccessibilityPermission.isTrusted(prompt: true)
    }
    refreshRuntime()
  }

  private func selectIntensity(_ intensity: ScrollIntensity) {
    guard configuration.intensity != intensity else { return }
    configuration.intensity = intensity
    configurationStore.save(configuration)
    eventTapController.intensity = intensity
    renderStatusMenu()
  }

  private func toggleStartAtLogin() {
    try? launchAtLoginManager.setEnabled(!launchAtLoginManager.isEnabled)
    renderStatusMenu()
  }

  private func requestAccessibilityAccess() {
    accessibilityTrusted = AccessibilityPermission.isTrusted(prompt: true)
    refreshRuntime()
  }

  private func refreshRuntime() {
    eventTapController.setEnabled(configuration.isEnabled && accessibilityTrusted)
  }

  private func renderStatusMenu() {
    let state = StatusMenuState(
      configuration: configuration,
      startAtLoginEnabled: launchAtLoginManager.isEnabled,
      accessibilityTrusted: accessibilityTrusted,
      tapStatus: tapStatus
    )
    guard lastMenuState != state else { return }
    lastMenuState = state
    statusMenuController.render(state)
  }

  private func startPermissionMonitor() {
    permissionMonitor?.cancel()
    permissionMonitor = Task { [weak self] in
      while !Task.isCancelled {
        try? await Task.sleep(for: .seconds(2))
        guard let self else { return }
        accessibilityTrusted = AccessibilityPermission.isTrusted(prompt: false)
        if accessibilityTrusted, configuration.isEnabled, !tapStatus.isEnabled {
          refreshRuntime()
        } else {
          renderStatusMenu()
        }
      }
    }
  }
}
