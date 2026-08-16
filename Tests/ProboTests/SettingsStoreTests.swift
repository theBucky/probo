import Foundation
import Testing

@testable import ProboCore

@Suite("Settings store")
struct SettingsStoreTests {
  @Test("registered defaults load default configuration")
  func registeredDefaults() {
    let isolated = IsolatedDefaults()

    #expect(SettingsStore(defaults: isolated.defaults).load() == AppConfiguration())
  }

  @Test("saved configuration round trips by key")
  func savedConfiguration() {
    let isolated = IsolatedDefaults()
    let store = SettingsStore(defaults: isolated.defaults)
    let configuration = AppConfiguration(
      isEnabled: false,
      input: InputConfiguration(
        wheelStep: .medium,
        isLookUpEnabled: false,
        isOptionPrecisionEnabled: true,
        isTerminalOptimizationEnabled: false,
        isTrackpadStyleScrollingEnabled: true
      ),
      preventsIdleSleep: true
    )

    store.save(configuration)

    #expect(store.load() == configuration)
  }

  @Test("invalid wheel step normalizes to slow")
  func invalidWheelStep() {
    let isolated = IsolatedDefaults()
    isolated.defaults.set(99, forKey: "wheelStep")

    #expect(SettingsStore(defaults: isolated.defaults).load().input.wheelStep == .slow)
  }
}
