import Darwin
import Observation
import os

@MainActor
@Observable
final class ProboModel {
  private static let enabledPermissionMonitorInterval: Duration = .seconds(2)
  private static let idlePermissionMonitorInterval: Duration = .seconds(15)

  private let configurationStore = AppConfigurationStore()
  private let launchAtLogin = LaunchAtLogin()
  private let eventTapController = EventTapController()
  private let logger = Logger(subsystem: "com.probo.app", category: "Probo")

  private var permissionMonitor: Task<Void, Never>?

  private(set) var configuration = AppConfiguration.defaultValue
  private(set) var tapStatus = EventTapController.Status(isInstalled: false, isEnabled: false)
  private(set) var accessibilityTrusted = false
  private(set) var startAtLoginEnabled = false

  var statusSymbolName: String {
    if !accessibilityTrusted { return "exclamationmark.triangle.fill" }
    if configuration.isEnabled && tapStatus.isEnabled { return "computermouse.fill" }
    return "computermouse"
  }

  func start() {
    configuration = configurationStore.load()
    startAtLoginEnabled = launchAtLogin.isEnabled
    eventTapController.apply(configuration: configuration)
    eventTapController.onStatusChange = { [weak self] status in
      self?.tapStatus = status
    }

    accessibilityTrusted = AccessibilityPermission.isTrusted(prompt: configuration.isEnabled)
    refreshRuntime()
    startPermissionMonitor()
  }

  func setEnabled(_ isEnabled: Bool) {
    mutate { $0.isEnabled = isEnabled }
    if isEnabled {
      accessibilityTrusted = AccessibilityPermission.isTrusted(prompt: true)
    }
    refreshRuntime()
    startPermissionMonitor()
  }

  func setIntensity(_ intensity: ScrollIntensity) {
    mutate { $0.intensity = intensity }
  }

  func setLookUpEnabled(_ isEnabled: Bool) {
    mutate { $0.isLookUpEnabled = isEnabled }
  }

  func setPrecisionScrollEnabled(_ isEnabled: Bool) {
    mutate { $0.isPrecisionScrollEnabled = isEnabled }
  }

  func setTrackpadStyleScrollingEnabled(_ isEnabled: Bool) {
    mutate { $0.isTrackpadStyleScrollingEnabled = isEnabled }
  }

  func setStartAtLoginEnabled(_ isEnabled: Bool) {
    do {
      try launchAtLogin.setEnabled(isEnabled)
      startAtLoginEnabled = launchAtLogin.isEnabled
    } catch {
      startAtLoginEnabled = launchAtLogin.isEnabled
      logger.error("failed to update launch at login: \(error.localizedDescription)")
    }
  }

  func requestAccessibilityAccess() {
    accessibilityTrusted = AccessibilityPermission.isTrusted(prompt: true)
    refreshRuntime()
  }

  func quit() {
    stop()
    exit(EXIT_SUCCESS)
  }

  private func mutate(_ change: (inout AppConfiguration) -> Void) {
    let old = configuration
    change(&configuration)
    guard configuration != old else { return }
    configurationStore.save(configuration)
    eventTapController.apply(configuration: configuration)
  }

  private func refreshRuntime() {
    eventTapController.setEnabled(configuration.isEnabled && accessibilityTrusted)
  }

  private func stop() {
    permissionMonitor?.cancel()
    eventTapController.teardown()
  }

  private func startPermissionMonitor() {
    permissionMonitor?.cancel()
    permissionMonitor = Task { [weak self] in
      while !Task.isCancelled {
        guard let self else { return }
        try? await Task.sleep(for: permissionMonitorInterval())
        guard !Task.isCancelled else { return }
        refreshSystemState()
      }
    }
  }

  private func permissionMonitorInterval() -> Duration {
    if configuration.isEnabled {
      return Self.enabledPermissionMonitorInterval
    }
    return Self.idlePermissionMonitorInterval
  }

  private func refreshSystemState() {
    let trusted = AccessibilityPermission.isTrusted(prompt: false)
    let loginEnabled = launchAtLogin.isEnabled
    if accessibilityTrusted != trusted { accessibilityTrusted = trusted }
    if startAtLoginEnabled != loginEnabled { startAtLoginEnabled = loginEnabled }
    if accessibilityTrusted, configuration.isEnabled, !tapStatus.isEnabled {
      refreshRuntime()
    }
  }
}
