import Foundation

let appConfigurationStoreTests: [TestCase] = [
  TestCase(
    behavior: "given no saved configuration when loading then it returns the default configuration"
  ) {
    try withIsolatedDefaults { defaults in
      let store = AppConfigurationStore(defaults: defaults)

      try expectEqual(
        store.load(),
        .defaultValue,
        "empty defaults suite should load the default configuration"
      )
    }
  },

  TestCase(
    behavior:
      "given no saved configuration when loading then automatic sleep prevention is disabled"
  ) {
    try withIsolatedDefaults { defaults in
      let store = AppConfigurationStore(defaults: defaults)

      try expectEqual(
        store.load().preventsAutomaticSleep,
        false,
        "automatic sleep prevention should be opt-in"
      )
    }
  },

  TestCase(
    behavior: "given a saved configuration when loading then it returns the saved configuration"
  ) {
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

      try expectEqual(store.load(), configuration, "saved configuration should load unchanged")
    }
  },

  TestCase(
    behavior: "given invalid stored configuration when loading then it returns the default"
  ) {
    try withIsolatedDefaults { defaults in
      defaults.set(Data("not a configuration".utf8), forKey: "configuration")
      let store = AppConfigurationStore(defaults: defaults)

      try expectEqual(
        store.load(),
        .defaultValue,
        "invalid stored data should not produce a partial configuration"
      )
    }
  },
]

private func withIsolatedDefaults(_ body: (UserDefaults) throws -> Void) throws {
  let suiteName = "com.probo.tests.\(UUID().uuidString)"
  let defaults = UserDefaults(suiteName: suiteName)!
  defaults.removePersistentDomain(forName: suiteName)
  defer { defaults.removePersistentDomain(forName: suiteName) }
  try body(defaults)
}
