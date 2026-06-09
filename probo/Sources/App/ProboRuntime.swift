import Foundation
import os

@MainActor
struct ProboRuntimeEnvironment {
  let loadConfiguration: () -> AppConfiguration
  let saveConfiguration: (AppConfiguration) -> Void
  let isAccessibilityTrusted: (_ prompt: Bool) -> Bool
  let isStartAtLoginEnabled: () -> Bool
  let setStartAtLoginEnabled: (Bool) throws -> Void
  let setFrontmostMonitorActive: (Bool) -> Void
  let startEventTap: (@escaping @MainActor (Bool) -> Void) -> Void
  let setEventTapConfiguration: (AppConfiguration) -> Void
  let setEventTapActive: (Bool) -> Void
  let setAutomaticSleepPreventionEnabled: (Bool) -> Void
  let makeAccessibilityGrantTask: (@escaping @MainActor () -> Void) -> Task<Void, Never>

  static func live() -> Self {
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
      startEventTap: { eventTapController.onTapEnabledChange = $0 },
      setEventTapConfiguration: { eventTapController.setConfiguration($0) },
      setEventTapActive: { eventTapController.setActive($0) },
      setAutomaticSleepPreventionEnabled: {
        automaticSleepPreventionController.setEnabled($0)
      },
      makeAccessibilityGrantTask: { onChange in
        Task { @MainActor in
          let stream = DistributedNotificationCenter.default()
            .notifications(named: AccessibilityPermission.trustChangedNotification)
          for await _ in stream {
            onChange()
          }
        }
      }
    )
  }
}

@MainActor
final class ProboRuntime {
  private let environment: ProboRuntimeEnvironment
  private var configuration: AppConfiguration
  private(set) var accessibilityTrusted = false
  private(set) var startAtLoginEnabled = false
  private var tapEnabled = false
  var onChange: (() -> Void)?

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

  private let logger = Logger(subsystem: "com.probo.app", category: "Probo")
  private var accessibilityGrantTask: Task<Void, Never>?

  convenience init() {
    self.init(environment: .live())
  }

  init(environment: ProboRuntimeEnvironment) {
    self.environment = environment
    configuration = environment.loadConfiguration()
  }

  func start() {
    environment.startEventTap { [weak self] enabled in
      self?.tapEnabled = enabled
      self?.onChange?()
    }
    refreshSystemState()
  }

  func refreshSystemState() {
    accessibilityTrusted = environment.isAccessibilityTrusted(false)
    startAtLoginEnabled = environment.isStartAtLoginEnabled()
    reconcile()
    onChange?()
  }

  func setStartAtLoginEnabled(_ isEnabled: Bool) {
    do {
      try environment.setStartAtLoginEnabled(isEnabled)
    } catch {
      logger.error("failed to update launch at login: \(error.localizedDescription)")
    }
    startAtLoginEnabled = environment.isStartAtLoginEnabled()
    onChange?()
  }

  func requestAccessibilityAccess() {
    accessibilityTrusted = environment.isAccessibilityTrusted(true)
    reconcile()
    onChange?()
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

  private func reconcile() {
    let tapActive = configuration.isEnabled && accessibilityTrusted
    environment.setFrontmostMonitorActive(tapActive && configuration.isTerminalOptimizationEnabled)
    environment.setEventTapConfiguration(configuration)
    environment.setEventTapActive(tapActive)
    environment.setAutomaticSleepPreventionEnabled(
      configuration.isEnabled && configuration.preventsAutomaticSleep
    )
    accessibilityTrusted ? stopAccessibilityGrantWatcher() : startAccessibilityGrantWatcher()
  }

  private func startAccessibilityGrantWatcher() {
    guard accessibilityGrantTask == nil else { return }
    accessibilityGrantTask = environment.makeAccessibilityGrantTask { [weak self] in
      self?.refreshSystemState()
    }
  }

  private func stopAccessibilityGrantWatcher() {
    accessibilityGrantTask?.cancel()
    accessibilityGrantTask = nil
  }

  deinit {
    accessibilityGrantTask?.cancel()
  }
}
