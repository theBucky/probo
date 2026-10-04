import Foundation
import Synchronization
import Testing

@testable import ProboCore

@Suite("Configuration")
struct ConfigurationTests {
  @Test("registered defaults load default configuration")
  func registeredDefaults() {
    let isolated = IsolatedDefaults()

    #expect(ConfigurationStore(defaults: isolated.defaults).load() == AppConfiguration())
  }

  @Test("saved configuration round trips by key")
  func savedConfiguration() {
    let isolated = IsolatedDefaults()
    let store = ConfigurationStore(defaults: isolated.defaults)
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

    #expect(ConfigurationStore(defaults: isolated.defaults).load().input.wheelStep == .slow)
  }

  @Test("input configuration round trips through an atomic")
  func atomicRoundTrip() {
    let configuration = InputConfiguration(
      wheelStep: .medium,
      isLookUpEnabled: false,
      isOptionPrecisionEnabled: true,
      isTerminalOptimizationEnabled: false,
      isTrackpadStyleScrollingEnabled: true
    )
    let atomic = Atomic<InputConfiguration>(InputConfiguration())

    atomic.store(configuration, ordering: .relaxed)

    #expect(atomic.load(ordering: .relaxed) == configuration)
  }
}
