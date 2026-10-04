import Foundation
import Observation
import os

package enum RuntimeStatus: Equatable {
  case idle
  case needsAccessibility
  case active
  // Trusted and enabled, yet the event tap could not be installed or has died.
  case tapFailed

  init(isEnabled: Bool, accessibilityTrusted: Bool, inputRunning: Bool) {
    self =
      switch (isEnabled, accessibilityTrusted, inputRunning) {
      case (false, _, _): .idle
      case (true, false, _): .needsAccessibility
      case (true, true, true): .active
      case (true, true, false): .tapFailed
      }
  }
}

@MainActor
@Observable
package final class Runtime {
  private let store: ConfigurationStore
  private let inputPipeline = InputPipeline()
  private let logger = Logger(subsystem: "com.probo.app", category: "Probo")
  @ObservationIgnored private var idleSleepAssertion: IdleSleepAssertion?
  @ObservationIgnored private var trustChangeObserver: Task<Void, Never>?

  package private(set) var accessibilityTrusted = false

  package var configuration: AppConfiguration {
    didSet {
      guard configuration != oldValue else { return }
      store.save(configuration)
      applyConfiguration()
      if configuration.isEnabled && !oldValue.isEnabled && !accessibilityTrusted {
        requestAccessibilityAccess()
      }
    }
  }

  // SMAppService has no change notification, so each read returns live state and the manual observation hooks only cover writes made here.
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
      inputRunning: inputPipeline.isRunning
    )
  }

  // Trust is never queried here, so constructing a Runtime touches no AX API and installs no tap; callers drive trust through `refreshAccessibility`.
  package init(store: ConfigurationStore = ConfigurationStore()) {
    self.store = store
    configuration = store.load()
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
    let preventsIdleSleep = configuration.isEnabled && configuration.preventsIdleSleep
    idleSleepAssertion = preventsIdleSleep ? idleSleepAssertion ?? IdleSleepAssertion() : nil
  }

  deinit {
    trustChangeObserver?.cancel()
  }
}
