import Darwin
import Foundation
import Observation
import os

@MainActor
@Observable
final class ProboModel {
  private let configurationStore = AppConfigurationStore()
  private let frontmostMonitor = FrontmostAppMonitor()
  private let eventTapController: EventTapController
  private let logger = Logger(subsystem: "com.probo.app", category: "Probo")

  init() {
    eventTapController = EventTapController(
      isTerminalFrontmost: { [frontmostMonitor] in frontmostMonitor.isTerminalFrontmost() }
    )
  }

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
    startAtLoginEnabled = LaunchAtLogin.isEnabled
    frontmostMonitor.start()
    eventTapController.apply(configuration: configuration)
    eventTapController.onStatusChange = { [weak self] status in
      self?.tapStatus = status
    }
    accessibilityTrusted = AccessibilityPermission.isTrusted(prompt: false)
    eventTapController.setEnabled(configuration.isEnabled && accessibilityTrusted)
    if configuration.isEnabled && !accessibilityTrusted {
      requestAccessibilityAccess()
    }
    observeAccessibility()
  }

  func setEnabled(_ isEnabled: Bool) {
    mutate { $0.isEnabled = isEnabled }
    eventTapController.setEnabled(isEnabled && accessibilityTrusted)
    if isEnabled && !accessibilityTrusted {
      requestAccessibilityAccess()
    }
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

  func setTerminalPrecisionEnabled(_ isEnabled: Bool) {
    mutate { $0.isTerminalPrecisionEnabled = isEnabled }
  }

  func setTrackpadStyleScrollingEnabled(_ isEnabled: Bool) {
    mutate { $0.isTrackpadStyleScrollingEnabled = isEnabled }
  }

  func setStartAtLoginEnabled(_ isEnabled: Bool) {
    Task.detached { [weak self, logger] in
      let resolved: Bool
      do {
        try LaunchAtLogin.setEnabled(isEnabled)
        resolved = isEnabled
      } catch {
        logger.error("failed to update launch at login: \(error.localizedDescription)")
        resolved = LaunchAtLogin.isEnabled
      }
      await self?.applyLaunchAtLogin(resolved)
    }
  }

  func refreshLaunchAtLogin() {
    startAtLoginEnabled = LaunchAtLogin.isEnabled
  }

  func requestAccessibilityAccess() {
    Task.detached { [weak self] in
      let trusted = AccessibilityPermission.isTrusted(prompt: true)
      await self?.applyAccessibilityTrust(trusted)
    }
  }

  func quit() {
    exit(EXIT_SUCCESS)
  }

  private func mutate(_ change: (inout AppConfiguration) -> Void) {
    let old = configuration
    change(&configuration)
    guard configuration != old else { return }
    configurationStore.save(configuration)
    eventTapController.apply(configuration: configuration)
  }

  private func applyLaunchAtLogin(_ enabled: Bool) {
    startAtLoginEnabled = enabled
  }

  private func applyAccessibilityTrust(_ trusted: Bool) {
    guard accessibilityTrusted != trusted else { return }
    accessibilityTrusted = trusted
    eventTapController.setEnabled(configuration.isEnabled && trusted)
  }

  private func observeAccessibility() {
    let stream = DistributedNotificationCenter.default()
      .notifications(named: AccessibilityPermission.trustChangedNotification)
    Task { [weak self] in
      for await _ in stream {
        guard let self else { return }
        let trusted = AccessibilityPermission.isTrusted(prompt: false)
        applyAccessibilityTrust(trusted)
      }
    }
  }
}
