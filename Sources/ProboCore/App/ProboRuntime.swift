import Foundation
import Observation
import os

@MainActor
package struct ProboRuntimeEnvironment {
  let loadConfiguration: () -> AppConfiguration
  let saveConfiguration: (AppConfiguration) -> Void
  let isAccessibilityTrusted: (_ prompt: Bool) -> Bool
  let isStartAtLoginEnabled: () -> Bool
  let setStartAtLoginEnabled: (Bool) throws -> Void
  let setFrontmostMonitorActive: (Bool) -> Void
  let setTapEnabledHandler: (@escaping @MainActor (Bool) -> Void) -> Void
  let setEventTapConfiguration: (AppConfiguration) -> Void
  let setEventTapActive: (Bool) -> Void
  let setAutomaticSleepPreventionEnabled: (Bool) -> Void
  let makeAccessibilityGrantTask: (@escaping @MainActor () -> Void) -> Task<Void, Never>

  package static func live() -> Self {
    let configurationStore = AppConfigurationStore()
    let frontmostMonitor = FrontmostAppMonitor()
    let eventTapController = EventTapController(
      isTerminalFrontmost: { [frontmostMonitor] in frontmostMonitor.isTerminalFrontmost() }
    )
    let automaticSleepPreventionController = AutomaticSleepPreventionController()

    return Self(
      loadConfiguration: { configurationStore.load() },
      saveConfiguration: { configurationStore.save($0) },
      isAccessibilityTrusted: { AccessibilityPermission.isTrusted(prompt: $0) },
      isStartAtLoginEnabled: { LaunchAtLogin.isEnabled },
      setStartAtLoginEnabled: { try LaunchAtLogin.setEnabled($0) },
      setFrontmostMonitorActive: { frontmostMonitor.setActive($0) },
      setTapEnabledHandler: { eventTapController.onTapEnabledChange = $0 },
      setEventTapConfiguration: { eventTapController.setConfiguration($0) },
      setEventTapActive: { eventTapController.setActive($0) },
      setAutomaticSleepPreventionEnabled: {
        automaticSleepPreventionController.setEnabled($0)
      },
      makeAccessibilityGrantTask: { AccessibilityPermission.makeGrantTask(onChange: $0) }
    )
  }
}

@MainActor
@Observable
package final class ProboRuntime {
  private let environment: ProboRuntimeEnvironment
  private var configuration: AppConfiguration
  package private(set) var accessibilityTrusted = false
  private var tapEnabled = false
  package var onChange: (() -> Void)?

  package var startAtLoginEnabled: Bool { environment.isStartAtLoginEnabled() }

  package var isEnabled: Bool {
    get { configuration.isEnabled }
    set {
      guard update(\.isEnabled, newValue) else { return }
      if newValue && !accessibilityTrusted {
        requestAccessibilityAccess()
      }
    }
  }

  package var intensity: ScrollIntensity {
    get { configuration.intensity }
    set { update(\.intensity, newValue) }
  }

  // Plain on/off settings with no side effects beyond persist-and-reconcile;
  // isEnabled stays a named property because enabling can prompt for accessibility.
  package subscript(toggle keyPath: WritableKeyPath<AppConfiguration, Bool>) -> Bool {
    get { configuration[keyPath: keyPath] }
    set { update(keyPath, newValue) }
  }

  package var statusSymbolName: String {
    if configuration.isEnabled && !accessibilityTrusted { return "exclamationmark.triangle.fill" }
    if configuration.isEnabled && tapEnabled { return "computermouse.fill" }
    return "computermouse"
  }

  private let logger = Logger(subsystem: "com.probo.app", category: "Probo")
  // ObservationIgnored keeps this a stored property so deinit can cancel it.
  @ObservationIgnored private var accessibilityGrantTask: Task<Void, Never>?

  package init(environment: ProboRuntimeEnvironment) {
    self.environment = environment
    configuration = environment.loadConfiguration()
    environment.setTapEnabledHandler { [weak self] enabled in
      self?.tapEnabled = enabled
      self?.onChange?()
    }
  }

  package func refreshAccessibility() {
    refreshAccessibility(prompt: false)
  }

  package func setStartAtLoginEnabled(_ isEnabled: Bool) {
    do {
      try environment.setStartAtLoginEnabled(isEnabled)
    } catch {
      logger.error("failed to update launch at login: \(error.localizedDescription)")
    }
    onChange?()
  }

  package func requestAccessibilityAccess() {
    refreshAccessibility(prompt: true)
  }

  @discardableResult
  private func update<T: Equatable>(
    _ keyPath: WritableKeyPath<AppConfiguration, T>,
    _ value: T
  ) -> Bool {
    guard configuration[keyPath: keyPath] != value else { return false }
    configuration[keyPath: keyPath] = value
    environment.saveConfiguration(configuration)
    reconcile()
    onChange?()
    return true
  }

  private func refreshAccessibility(prompt: Bool) {
    accessibilityTrusted = environment.isAccessibilityTrusted(prompt)
    reconcile()
    onChange?()
  }

  private func reconcile() {
    let tapActive = configuration.isEnabled && accessibilityTrusted
    environment.setFrontmostMonitorActive(tapActive && configuration.isTerminalOptimizationEnabled)
    environment.setEventTapConfiguration(configuration)
    environment.setEventTapActive(tapActive)
    environment.setAutomaticSleepPreventionEnabled(
      configuration.isEnabled && configuration.preventsAutomaticSleep
    )
    if accessibilityTrusted {
      accessibilityGrantTask?.cancel()
      accessibilityGrantTask = nil
    } else if accessibilityGrantTask == nil {
      accessibilityGrantTask = environment.makeAccessibilityGrantTask { [weak self] in
        self?.refreshAccessibility()
      }
    }
  }

  deinit {
    accessibilityGrantTask?.cancel()
  }
}
