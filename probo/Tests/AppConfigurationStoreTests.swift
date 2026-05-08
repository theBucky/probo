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
    behavior: "given a saved configuration when loading then it returns the saved configuration"
  ) {
    try withIsolatedDefaults { defaults in
      let store = AppConfigurationStore(defaults: defaults)
      let configuration = AppConfiguration(
        isEnabled: false,
        intensity: .medium,
        isLookUpEnabled: false,
        isOptionPrecisionEnabled: true,
        isTerminalDefaultPrecisionEnabled: false,
        isTrackpadStyleScrollingEnabled: true
      )

      store.save(configuration)

      try expectEqual(store.load(), configuration, "saved configuration should load unchanged")
    }
  },

  TestCase(
    behavior:
      "given partial invalid saved configuration when loading then it keeps valid values and defaults the rest"
  ) {
    try withIsolatedDefaults { defaults in
      defaults.set(false, forKey: "isEnabled")
      defaults.set(99, forKey: "intensity")
      defaults.set(true, forKey: "isOptionPrecisionEnabled")
      let store = AppConfigurationStore(defaults: defaults)
      var expected = AppConfiguration.defaultValue
      expected.isEnabled = false
      expected.isOptionPrecisionEnabled = true

      try expectEqual(
        store.load(),
        expected,
        "valid stored values should survive while invalid or missing values use defaults"
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
