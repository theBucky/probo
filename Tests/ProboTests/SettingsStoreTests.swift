import Foundation
import Testing

@testable import ProboCore

@Suite("Settings store")
struct SettingsStoreTests {
  @Test("registered defaults load default configuration")
  func registeredDefaults() throws {
    try withIsolatedDefaults { defaults in
      #expect(SettingsStore(defaults: defaults).load() == AppConfiguration())
    }
  }

  @Test("saved configuration round trips by key")
  func savedConfiguration() throws {
    try withIsolatedDefaults { defaults in
      let store = SettingsStore(defaults: defaults)
      let configuration = AppConfiguration(
        isEnabled: false,
        wheelStep: .medium,
        isLookUpEnabled: false,
        isOptionPrecisionEnabled: true,
        isTerminalOptimizationEnabled: false,
        isTrackpadStyleScrollingEnabled: true,
        preventsIdleSleep: true
      )

      store.save(configuration)

      #expect(store.load() == configuration)
    }
  }

  @Test("invalid wheel step normalizes to slow")
  func invalidWheelStep() throws {
    try withIsolatedDefaults { defaults in
      defaults.set(99, forKey: "wheelStep")

      #expect(SettingsStore(defaults: defaults).load().wheelStep == .slow)
    }
  }
}

private func withIsolatedDefaults(_ body: (UserDefaults) throws -> Void) throws {
  let suiteName = "com.probo.tests.\(UUID().uuidString)"
  let defaults = UserDefaults(suiteName: suiteName)!
  defaults.removePersistentDomain(forName: suiteName)
  defer { defaults.removePersistentDomain(forName: suiteName) }
  try body(defaults)
}
