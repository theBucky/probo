import AppKit
import os

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
  private let launchAtLogin = LaunchAtLogin()
  private let eventTapController = EventTapController()
  private let statusMenuController = StatusMenuController()

  private var configuration = AppConfiguration.defaultValue
  private var tapStatus = EventTapController.Status(isInstalled: false, isEnabled: false)
  private var accessibilityTrusted = false
  private var lastMenuState: StatusMenuState?
  private var permissionMonitor: Task<Void, Never>?

  func applicationDidFinishLaunching(_ notification: Notification) {
    configuration = configurationStore.load()
    eventTapController.apply(configuration: configuration)
    wireMenuActions()
    eventTapController.onStatusChange = { [weak self] status in
      guard let self else { return }
      tapStatus = status
      renderStatusMenu()
    }

    accessibilityTrusted = AccessibilityPermission.isTrusted(prompt: configuration.isEnabled)
    refreshRuntime()
    startPermissionMonitor()
  }

  func applicationWillTerminate(_ notification: Notification) {
    permissionMonitor?.cancel()
    eventTapController.teardown()
  }

  private func wireMenuActions() {
    statusMenuController.onToggleEnabled = { [weak self] in self?.toggleEnabled() }
    statusMenuController.onSelectIntensity = { [weak self] in self?.selectIntensity($0) }
    statusMenuController.onToggleLookUp = { [weak self] in self?.toggleLookUp() }
    statusMenuController.onTogglePrecisionScroll = { [weak self] in self?.togglePrecisionScroll() }
    statusMenuController.onToggleStartAtLogin = { [weak self] in self?.toggleStartAtLogin() }
    statusMenuController.onGrantAccessibilityAccess = { [weak self] in
      self?.requestAccessibilityAccess()
    }
    statusMenuController.onQuit = { NSApplication.shared.terminate(nil) }
  }

  private func mutate(_ change: (inout AppConfiguration) -> Void) {
    change(&configuration)
    configurationStore.save(configuration)
    eventTapController.apply(configuration: configuration)
    renderStatusMenu()
  }

  private func toggleEnabled() {
    mutate { $0.isEnabled.toggle() }
    if configuration.isEnabled {
      accessibilityTrusted = AccessibilityPermission.isTrusted(prompt: true)
    }
    refreshRuntime()
  }

  private func selectIntensity(_ intensity: ScrollIntensity) {
    guard configuration.intensity != intensity else { return }
    mutate { $0.intensity = intensity }
  }

  private func toggleLookUp() {
    mutate { $0.isLookUpEnabled.toggle() }
  }

  private func togglePrecisionScroll() {
    mutate { $0.isPrecisionScrollEnabled.toggle() }
  }

  private func toggleStartAtLogin() {
    do {
      try launchAtLogin.setEnabled(!launchAtLogin.isEnabled)
    } catch {
      Logger(subsystem: "com.probo.app", category: "AppDelegate")
        .error("failed to update launch at login: \(error.localizedDescription)")
    }
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
      startAtLoginEnabled: launchAtLogin.isEnabled,
      accessibilityTrusted: accessibilityTrusted,
      tapStatus: tapStatus
    )
    guard lastMenuState != state else { return }
    lastMenuState = state
    statusMenuController.render(state)
  }

  private func startPermissionMonitor() {
    permissionMonitor = Task { [weak self] in
      while !Task.isCancelled {
        try? await Task.sleep(for: .seconds(2))
        guard let self else { return }
        accessibilityTrusted = AccessibilityPermission.isTrusted(prompt: false)
        if accessibilityTrusted, configuration.isEnabled, !tapStatus.isEnabled {
          refreshRuntime()
        }
        renderStatusMenu()
      }
    }
  }
}
