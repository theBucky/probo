import Foundation
import Observation
import os

package enum RuntimeStatus: Equatable {
  case needsAccessibility
  case active
  case idle

  package init(isEnabled: Bool, accessibilityTrusted: Bool, tapEnabled: Bool) {
    self =
      switch (isEnabled, accessibilityTrusted, tapEnabled) {
      case (false, _, _): .idle
      case (true, false, _): .needsAccessibility
      case (true, true, true): .active
      case (true, true, false): .idle
      }
  }
}

package struct SystemPlan: Equatable {
  package var tapActive: Bool
  package var frontmostMonitorActive: Bool
  package var preventsIdleSleep: Bool
  package var tapOptions: TapOptions

  package init(configuration: AppConfiguration, accessibilityTrusted: Bool) {
    tapActive = configuration.isEnabled && accessibilityTrusted
    frontmostMonitorActive = tapActive && configuration.isTerminalOptimizationEnabled
    preventsIdleSleep = configuration.isEnabled && configuration.preventsIdleSleep
    tapOptions = TapOptions(configuration: configuration)
  }
}

@MainActor
@Observable
package final class Runtime {
  private let settingsStore: SettingsStore
  private let frontmostMonitor: FrontmostAppMonitor
  private let eventTap: EventTap
  private let idleSleepAssertion: IdleSleepAssertion
  package private(set) var accessibilityTrusted = false
  private var tapEnabled = false

  package var configuration: AppConfiguration {
    didSet {
      guard configuration != oldValue else { return }
      settingsStore.save(configuration)
      reconcile()
      if configuration.isEnabled && !oldValue.isEnabled && !accessibilityTrusted {
        requestAccessibilityAccess()
      }
    }
  }

  package var startAtLoginEnabled: Bool { LaunchAtLogin.isEnabled }

  package var status: RuntimeStatus {
    RuntimeStatus(
      isEnabled: configuration.isEnabled,
      accessibilityTrusted: accessibilityTrusted,
      tapEnabled: tapEnabled
    )
  }

  private let logger = Logger(subsystem: "com.probo.app", category: "Probo")
  @ObservationIgnored private var trustChangeObserver: Task<Void, Never>?

  package init(settingsStore: SettingsStore = SettingsStore()) {
    let frontmostMonitor = FrontmostAppMonitor()
    self.settingsStore = settingsStore
    self.frontmostMonitor = frontmostMonitor
    eventTap = EventTap(isTerminalFrontmost: { frontmostMonitor.isTerminalFrontmost() })
    idleSleepAssertion = IdleSleepAssertion()
    configuration = settingsStore.load()
    eventTap.onTapEnabledChange = { [weak self] enabled in
      self?.tapEnabled = enabled
    }
    // Trust moves both ways at any time (grant in the permission prompt, revoke in
    // System Settings), so the observer lives as long as the runtime.
    trustChangeObserver = AccessibilityPermission.observeTrustChanges { [weak self] in
      self?.refreshAccessibility()
    }
  }

  package func refreshAccessibility() {
    refreshAccessibility(prompt: false)
  }

  package func setStartAtLoginEnabled(_ isEnabled: Bool) {
    do {
      try LaunchAtLogin.setEnabled(isEnabled)
    } catch {
      logger.error("failed to update launch at login: \(error.localizedDescription)")
    }
  }

  package func requestAccessibilityAccess() {
    refreshAccessibility(prompt: true)
  }

  private func refreshAccessibility(prompt: Bool) {
    accessibilityTrusted = AccessibilityPermission.isTrusted(prompt: prompt)
    reconcile()
  }

  private func reconcile() {
    let plan = SystemPlan(configuration: configuration, accessibilityTrusted: accessibilityTrusted)
    frontmostMonitor.setActive(plan.frontmostMonitorActive)
    eventTap.setOptions(plan.tapOptions)
    eventTap.setActive(plan.tapActive)
    idleSleepAssertion.setEnabled(plan.preventsIdleSleep)
  }

  deinit {
    trustChangeObserver?.cancel()
  }
}
