import Foundation
import Observation
import os

@MainActor
@Observable
final class ProboRuntime {
  private var configuration: AppConfiguration
  private(set) var accessibilityTrusted = false
  private(set) var startAtLoginEnabled = false
  private var tapEnabled = false

  var isEnabled: Bool {
    get { configuration.isEnabled }
    set {
      guard update(\.isEnabled, newValue) else { return }
      if newValue && !accessibilityTrusted {
        requestAccessibilityAccess()
      }
    }
  }

  var intensity: ScrollIntensity {
    get { configuration.intensity }
    set { update(\.intensity, newValue) }
  }

  var isLookUpEnabled: Bool {
    get { configuration.isLookUpEnabled }
    set { update(\.isLookUpEnabled, newValue) }
  }

  var isOptionPrecisionEnabled: Bool {
    get { configuration.isOptionPrecisionEnabled }
    set { update(\.isOptionPrecisionEnabled, newValue) }
  }

  var isTerminalOptimizationEnabled: Bool {
    get { configuration.isTerminalOptimizationEnabled }
    set { update(\.isTerminalOptimizationEnabled, newValue) }
  }

  var isTrackpadStyleScrollingEnabled: Bool {
    get { configuration.isTrackpadStyleScrollingEnabled }
    set { update(\.isTrackpadStyleScrollingEnabled, newValue) }
  }

  var preventsAutomaticSleep: Bool {
    get { configuration.preventsAutomaticSleep }
    set { update(\.preventsAutomaticSleep, newValue) }
  }

  var statusSymbolName: String {
    if configuration.isEnabled && !accessibilityTrusted { return "exclamationmark.triangle.fill" }
    if configuration.isEnabled && tapEnabled { return "computermouse.fill" }
    return "computermouse"
  }

  @ObservationIgnored
  private let frontmostMonitor = FrontmostAppMonitor()
  @ObservationIgnored
  private let eventTapController: EventTapController
  @ObservationIgnored
  private let automaticSleepPreventionController = AutomaticSleepPreventionController()
  @ObservationIgnored
  private let configurationStore = AppConfigurationStore()
  @ObservationIgnored
  private let logger = Logger(subsystem: "com.probo.app", category: "Probo")
  @ObservationIgnored
  private var accessibilityGrantTask: Task<Void, Never>?

  init() {
    configuration = configurationStore.load()
    eventTapController = EventTapController(
      isTerminalFrontmost: { [frontmostMonitor] in frontmostMonitor.isTerminalFrontmost() }
    )
  }

  func start() {
    eventTapController.onTapEnabledChange = { [weak self] enabled in
      self?.tapEnabled = enabled
    }
    refreshSystemState()
  }

  func refreshSystemState() {
    accessibilityTrusted = AccessibilityPermission.isTrusted(prompt: false)
    startAtLoginEnabled = LaunchAtLogin.isEnabled
    reconcile()
  }

  func setStartAtLoginEnabled(_ isEnabled: Bool) {
    do {
      try LaunchAtLogin.setEnabled(isEnabled)
    } catch {
      logger.error("failed to update launch at login: \(error.localizedDescription)")
    }
    startAtLoginEnabled = LaunchAtLogin.isEnabled
  }

  func requestAccessibilityAccess() {
    accessibilityTrusted = AccessibilityPermission.isTrusted(prompt: true)
    reconcile()
  }

  @discardableResult
  private func update<T: Equatable>(
    _ keyPath: WritableKeyPath<AppConfiguration, T>,
    _ value: T
  ) -> Bool {
    guard configuration[keyPath: keyPath] != value else { return false }
    configuration[keyPath: keyPath] = value
    configurationStore.save(configuration)
    reconcile()
    return true
  }

  private func reconcile() {
    let tapActive = configuration.isEnabled && accessibilityTrusted
    frontmostMonitor.setActive(tapActive && configuration.isTerminalOptimizationEnabled)
    eventTapController.setConfiguration(configuration)
    eventTapController.setActive(tapActive)
    automaticSleepPreventionController.setEnabled(
      configuration.isEnabled && configuration.preventsAutomaticSleep
    )
    // Watch grants whenever access isn't trusted: the settings form surfaces the request button
    // and "Required" label even while disabled, so the UI must observe grants regardless of state.
    if accessibilityTrusted {
      accessibilityGrantTask?.cancel()
      accessibilityGrantTask = nil
    } else {
      startAccessibilityGrantWatcher()
    }
  }

  private func startAccessibilityGrantWatcher() {
    guard accessibilityGrantTask == nil else { return }
    let stream = DistributedNotificationCenter.default()
      .notifications(named: AccessibilityPermission.trustChangedNotification)
    accessibilityGrantTask = Task { [weak self] in
      for await _ in stream {
        guard let self else { return }
        accessibilityTrusted = AccessibilityPermission.isTrusted(prompt: false)
        reconcile()
        if accessibilityTrusted { return }
      }
    }
  }
}
