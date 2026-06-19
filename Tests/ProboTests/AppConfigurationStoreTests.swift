import Foundation
import Testing

@testable import ProboCore

@Suite("App configuration store")
struct AppConfigurationStoreTests {
  @Test("missing saved configuration loads default configuration")
  func missingSavedConfiguration() throws {
    try withIsolatedDefaults { defaults in
      let store = AppConfigurationStore(defaults: defaults)

      #expect(store.load() == .defaultValue)
    }
  }

  @Test("saved configuration loads unchanged")
  func savedConfiguration() throws {
    try withIsolatedDefaults { defaults in
      let store = AppConfigurationStore(defaults: defaults)
      let configuration = AppConfiguration(
        isEnabled: false,
        intensity: .medium,
        isLookUpEnabled: false,
        isOptionPrecisionEnabled: true,
        isTerminalOptimizationEnabled: false,
        isTrackpadStyleScrollingEnabled: true,
        preventsAutomaticSleep: true
      )

      store.save(configuration)

      #expect(store.load() == configuration)
    }
  }

  @Test("invalid stored configuration loads default configuration")
  func invalidStoredConfiguration() throws {
    try withIsolatedDefaults { defaults in
      defaults.set(Data("not a configuration".utf8), forKey: "configuration")
      let store = AppConfigurationStore(defaults: defaults)

      #expect(store.load() == .defaultValue)
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
