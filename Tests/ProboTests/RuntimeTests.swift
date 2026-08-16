import Foundation
import Testing

@testable import ProboCore

@Suite("Runtime")
struct RuntimeTests {
  @Test("configuration changes persist through the store")
  @MainActor
  func configurationPersistence() {
    let isolated = IsolatedDefaults()
    let store = SettingsStore(defaults: isolated.defaults)
    let runtime = Runtime(settingsStore: store)

    runtime.configuration.input.wheelStep = .medium
    runtime.configuration.isEnabled = false

    #expect(store.load() == runtime.configuration)
    #expect(runtime.configuration.input.wheelStep == .medium)
    #expect(runtime.status == .idle)
  }

  @Test("status reflects enablement, trust, and input pipeline state")
  func status() {
    #expect(
      RuntimeStatus(isEnabled: true, accessibilityTrusted: false, inputRunning: false)
        == .needsAccessibility)
    #expect(
      RuntimeStatus(isEnabled: true, accessibilityTrusted: true, inputRunning: true) == .active)
    #expect(
      RuntimeStatus(isEnabled: true, accessibilityTrusted: true, inputRunning: false) == .idle)
    #expect(
      RuntimeStatus(isEnabled: false, accessibilityTrusted: true, inputRunning: false) == .idle)
  }
}
