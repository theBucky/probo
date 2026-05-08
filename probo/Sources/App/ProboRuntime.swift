import Foundation
import os

@MainActor
final class ProboRuntime {
  private let frontmostMonitor = FrontmostAppMonitor()
  private let eventTapController: EventTapController
  private let configurationStore = AppConfigurationStore()
  private let logger = Logger(subsystem: "com.probo.app", category: "Probo")
  private var configuration: AppConfiguration
  private var accessibilityGrantTask: Task<Void, Never>?

  var onConfigurationChange: ((AppConfiguration) -> Void)?
  var onAccessibilityTrustChange: ((Bool) -> Void)?
  var onStartAtLoginChange: ((Bool) -> Void)?
  var onTapStatusChange: ((EventTapController.Status) -> Void)?

  init() {
    configuration = configurationStore.load()
    eventTapController = EventTapController(
      isTerminalFrontmost: { [frontmostMonitor] in frontmostMonitor.isTerminalFrontmost() }
    )
  }

  func start() {
    frontmostMonitor.start()
    eventTapController.onStatusChange = { [weak self] status in
      self?.onTapStatusChange?(status)
    }
    onConfigurationChange?(configuration)
    eventTapController.apply(configuration: configuration)

    guard configuration.isEnabled else { return }
    applyAccessibilityTrust(AccessibilityPermission.isTrusted(prompt: false))
  }

  func refreshExternalState() {
    refreshConfiguration()
    applyAccessibilityTrust(AccessibilityPermission.isTrusted(prompt: false))
    onStartAtLoginChange?(LaunchAtLogin.isEnabled)
  }

  func setEnabled(_ isEnabled: Bool) {
    updateConfiguration { $0.isEnabled = isEnabled }
    guard isEnabled else {
      eventTapController.setEnabled(false)
      return
    }
    requestAccessibilityAccess()
  }

  func setStartAtLoginEnabled(_ isEnabled: Bool) {
    do {
      try LaunchAtLogin.setEnabled(isEnabled)
      onStartAtLoginChange?(isEnabled)
    } catch {
      logger.error("failed to update launch at login: \(error.localizedDescription)")
      onStartAtLoginChange?(LaunchAtLogin.isEnabled)
    }
  }

  func requestAccessibilityAccess() {
    let trusted = AccessibilityPermission.isTrusted(prompt: true)
    applyAccessibilityTrust(trusted)
    if !trusted {
      waitForAccessibilityGrant()
    }
  }

  private func waitForAccessibilityGrant() {
    accessibilityGrantTask?.cancel()
    let stream = DistributedNotificationCenter.default()
      .notifications(named: AccessibilityPermission.trustChangedNotification)
    accessibilityGrantTask = Task { [weak self] in
      for await _ in stream {
        guard let self else { return }
        let trusted = AccessibilityPermission.isTrusted(prompt: false)
        applyAccessibilityTrust(trusted)
        if trusted { return }
      }
    }
  }

  private func applyAccessibilityTrust(_ trusted: Bool) {
    onAccessibilityTrustChange?(trusted)
    eventTapController.setEnabled(configuration.isEnabled && trusted)
  }

  private func refreshConfiguration() {
    let loaded = configurationStore.load()
    guard loaded != configuration else { return }
    configuration = loaded
    onConfigurationChange?(configuration)
    eventTapController.apply(configuration: configuration)
  }

  func updateConfiguration(_ change: (inout AppConfiguration) -> Void) {
    var next = configuration
    change(&next)
    guard next != configuration else { return }

    configuration = next
    configurationStore.save(configuration)
    onConfigurationChange?(configuration)
    eventTapController.apply(configuration: configuration)
  }
}
