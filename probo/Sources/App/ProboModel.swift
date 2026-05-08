import Darwin
import Foundation
import Observation
import os

@MainActor
@Observable
final class ProboModel {
  private let configurationStore = AppConfigurationStore()
  private let launchAtLogin = LaunchAtLogin()
  private let frontmostMonitor = FrontmostAppMonitor()
  private let eventTapController: EventTapController
  private let logger = Logger(subsystem: "com.probo.app", category: "Probo")

  private var accessibilityObservation: Task<Void, Never>?

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
    startAtLoginEnabled = launchAtLogin.isEnabled
    frontmostMonitor.start()
    eventTapController.apply(configuration: configuration)
    eventTapController.onStatusChange = { [weak self] status in
      self?.tapStatus = status
    }

    accessibilityTrusted = AccessibilityPermission.isTrusted(prompt: configuration.isEnabled)
    refreshRuntime()
    observeAccessibility()
  }

  func setEnabled(_ isEnabled: Bool) {
    mutate { $0.isEnabled = isEnabled }
    if isEnabled {
      accessibilityTrusted = AccessibilityPermission.isTrusted(prompt: true)
    }
    refreshRuntime()
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
    do {
      try launchAtLogin.setEnabled(isEnabled)
      startAtLoginEnabled = launchAtLogin.isEnabled
    } catch {
      startAtLoginEnabled = launchAtLogin.isEnabled
      logger.error("failed to update launch at login: \(error.localizedDescription)")
    }
  }

  func refreshLaunchAtLogin() {
    let enabled = launchAtLogin.isEnabled
    guard startAtLoginEnabled != enabled else { return }
    startAtLoginEnabled = enabled
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

  private func observeAccessibility() {
    let stream = DistributedNotificationCenter.default()
      .notifications(named: AccessibilityPermission.trustChangedNotification)
    accessibilityObservation = Task { [weak self] in
      for await _ in stream {
        guard let self else { return }
        refreshAccessibility()
      }
    }
  }

  private func stop() {
    accessibilityObservation?.cancel()
    frontmostMonitor.stop()
    eventTapController.teardown()
  }

  private func refreshAccessibility() {
    let trusted = AccessibilityPermission.isTrusted(prompt: false)
    guard accessibilityTrusted != trusted else { return }
    accessibilityTrusted = trusted
    refreshRuntime()
  }
}
