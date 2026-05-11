import Foundation
import Observation
import os

@MainActor
@Observable
final class ProboRuntime {
  private var configuration: AppConfiguration
  private(set) var accessibilityTrusted = false
  private(set) var startAtLoginEnabled = false
  private var tapStatus = EventTapController.Status(isInstalled: false, isEnabled: false)

  var isEnabled: Bool {
    get { configuration.isEnabled }
    set { setEnabled(newValue) }
  }

  var intensity: ScrollIntensity {
    get { configuration.intensity }
    set { updateConfiguration { $0.intensity = newValue } }
  }

  var isLookUpEnabled: Bool {
    get { configuration.isLookUpEnabled }
    set { updateConfiguration { $0.isLookUpEnabled = newValue } }
  }

  var isOptionPrecisionEnabled: Bool {
    get { configuration.isOptionPrecisionEnabled }
    set { updateConfiguration { $0.isOptionPrecisionEnabled = newValue } }
  }

  var isTerminalDefaultPrecisionEnabled: Bool {
    get { configuration.isTerminalDefaultPrecisionEnabled }
    set { updateConfiguration { $0.isTerminalDefaultPrecisionEnabled = newValue } }
  }

  var isTrackpadStyleScrollingEnabled: Bool {
    get { configuration.isTrackpadStyleScrollingEnabled }
    set { updateConfiguration { $0.isTrackpadStyleScrollingEnabled = newValue } }
  }

  var preventsAutomaticSleep: Bool {
    get { configuration.preventsAutomaticSleep }
    set { updateConfiguration { $0.preventsAutomaticSleep = newValue } }
  }

  var statusSymbolName: String {
    if configuration.isEnabled && !accessibilityTrusted { return "exclamationmark.triangle.fill" }
    if configuration.isEnabled && tapStatus.isEnabled { return "computermouse.fill" }
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
    eventTapController.onStatusChange = { [weak self] status in
      self?.tapStatus = status
    }
    refreshSystemState()
  }

  func refreshSystemState() {
    accessibilityTrusted = AccessibilityPermission.isTrusted(prompt: false)
    startAtLoginEnabled = LaunchAtLogin.isEnabled
    reconcile()
  }

  private func setEnabled(_ isEnabled: Bool) {
    updateConfiguration { $0.isEnabled = isEnabled }
    if isEnabled {
      requestAccessibilityAccess()
    } else {
      accessibilityGrantTask?.cancel()
      accessibilityGrantTask = nil
    }
  }

  func setStartAtLoginEnabled(_ isEnabled: Bool) {
    do {
      try LaunchAtLogin.setEnabled(isEnabled)
      startAtLoginEnabled = LaunchAtLogin.isEnabled
    } catch {
      logger.error("failed to update launch at login: \(error.localizedDescription)")
      startAtLoginEnabled = LaunchAtLogin.isEnabled
    }
  }

  func requestAccessibilityAccess() {
    accessibilityTrusted = AccessibilityPermission.isTrusted(prompt: true)
    reconcile()
    if accessibilityTrusted {
      accessibilityGrantTask?.cancel()
      accessibilityGrantTask = nil
      return
    }

    waitForAccessibilityGrant()
  }

  private func waitForAccessibilityGrant() {
    accessibilityGrantTask?.cancel()
    let stream = DistributedNotificationCenter.default()
      .notifications(named: AccessibilityPermission.trustChangedNotification)
    accessibilityGrantTask = Task { [weak self] in
      for await _ in stream {
        guard let self else { return }
        accessibilityTrusted = AccessibilityPermission.isTrusted(prompt: false)
        reconcile()
        if accessibilityTrusted {
          accessibilityGrantTask = nil
          return
        }
      }
    }
  }

  private func updateConfiguration(_ change: (inout AppConfiguration) -> Void) {
    var next = configuration
    change(&next)
    guard next != configuration else { return }

    configuration = next
    configurationStore.save(configuration)
    reconcile()
  }

  private func reconcile() {
    let tapActive = configuration.isEnabled && accessibilityTrusted
    frontmostMonitor.setActive(tapActive && configuration.isTerminalDefaultPrecisionEnabled)
    eventTapController.setConfiguration(configuration)
    eventTapController.setActive(tapActive)
    automaticSleepPreventionController.setEnabled(
      configuration.isEnabled && configuration.preventsAutomaticSleep
    )
  }
}
