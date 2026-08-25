import Foundation
import Observation
import os

package enum RuntimeStatus: Equatable {
  case needsAccessibility
  case active
  case idle

  package init(isEnabled: Bool, accessibilityTrusted: Bool, inputRunning: Bool) {
    self =
      switch (isEnabled, accessibilityTrusted, inputRunning) {
      case (false, _, _): .idle
      case (true, false, _): .needsAccessibility
      case (true, true, true): .active
      case (true, true, false): .idle
      }
  }
}

@MainActor
@Observable
package final class Runtime {
  private let settingsStore: SettingsStore
  @ObservationIgnored private lazy var inputPipeline = InputPipeline { [weak self] isRunning in
    self?.inputRunning = isRunning
  }
  private let idleSleepAssertion = IdleSleepAssertion()
  private let logger = Logger(subsystem: "com.probo.app", category: "Probo")
  @ObservationIgnored private var trustChangeObserver: Task<Void, Never>?
  package private(set) var accessibilityTrusted = false
  private var inputRunning = false

  package var configuration: AppConfiguration {
    didSet {
      guard configuration != oldValue else { return }
      settingsStore.save(configuration)
      applyConfiguration()
      if configuration.isEnabled && !oldValue.isEnabled && !accessibilityTrusted {
        requestAccessibilityAccess()
      }
    }
  }

  // Projects SMAppService state through manual observation hooks so menu toggles
  // can bind to it. External changes (System Settings) don't notify; each read
  // still returns live service state.
  package var startAtLoginEnabled: Bool {
    get {
      access(keyPath: \.startAtLoginEnabled)
      return LaunchAtLogin.isEnabled
    }
    set {
      withMutation(keyPath: \.startAtLoginEnabled) {
        do {
          try LaunchAtLogin.setEnabled(newValue)
        } catch {
          logger.error("failed to update launch at login: \(error.localizedDescription)")
        }
      }
    }
  }

  package var status: RuntimeStatus {
    RuntimeStatus(
      isEnabled: configuration.isEnabled,
      accessibilityTrusted: accessibilityTrusted,
      inputRunning: inputRunning
    )
  }

  package init(settingsStore: SettingsStore = SettingsStore()) {
    self.settingsStore = settingsStore
    configuration = settingsStore.load()
    // Trust moves both ways at any time, so the observer lives as long as the runtime.
    trustChangeObserver = AccessibilityPermission.observeTrustChanges { [weak self] in
      self?.refreshAccessibility()
    }
  }

  package func refreshAccessibility() {
    updateAccessibility(AccessibilityPermission.isTrusted)
  }

  package func requestAccessibilityAccess() {
    updateAccessibility(AccessibilityPermission.request())
  }

  private func updateAccessibility(_ isTrusted: Bool) {
    accessibilityTrusted = isTrusted
    applyConfiguration()
  }

  private func applyConfiguration() {
    inputPipeline.apply(
      configuration.input,
      isEnabled: configuration.isEnabled && accessibilityTrusted
    )
    idleSleepAssertion.setEnabled(configuration.isEnabled && configuration.preventsIdleSleep)
  }

  deinit {
    trustChangeObserver?.cancel()
  }
}
