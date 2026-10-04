import Foundation
import Testing

@testable import ProboCore

@Suite("Runtime")
struct RuntimeTests {
  @Test("configuration loads from the store and writes every change back")
  @MainActor
  func configurationPersistence() {
    let isolated = IsolatedDefaults()
    let store = ConfigurationStore(defaults: isolated.defaults)
    let saved = AppConfiguration(
      isEnabled: false,
      input: InputConfiguration(wheelStep: .medium),
      preventsIdleSleep: true
    )
    store.save(saved)
    let runtime = Runtime(store: store)

    #expect(runtime.configuration == saved)

    runtime.configuration.input.isOptionPrecisionEnabled = true
    runtime.configuration.preventsIdleSleep = false

    #expect(store.load() == runtime.configuration)
  }

  @Test("status follows enablement while accessibility stays untrusted")
  @MainActor
  func statusWithoutTrust() {
    let isolated = IsolatedDefaults()
    let runtime = Runtime(store: ConfigurationStore(defaults: isolated.defaults))

    #expect(runtime.status == .needsAccessibility)

    runtime.configuration.isEnabled = false

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
      RuntimeStatus(isEnabled: true, accessibilityTrusted: true, inputRunning: false) == .tapFailed)
    #expect(
      RuntimeStatus(isEnabled: false, accessibilityTrusted: true, inputRunning: false) == .idle)
  }
}
