import Foundation

let appConfigurationStoreTests: [TestCase] = [
  TestCase(
    behavior: "given an empty defaults suite when loading then it returns registered defaults"
  ) {
    try withIsolatedDefaults { defaults in
      let store = AppConfigurationStore(defaults: defaults)

      try expectEqual(
        store.load(),
        .defaultValue,
        "empty defaults suite should load app defaults"
      )
    }
  },

  TestCase(
    behavior: "given a saved configuration when loading then it round-trips every field"
  ) {
    try withIsolatedDefaults { defaults in
      let store = AppConfigurationStore(defaults: defaults)
      let configuration = AppConfiguration(
        isEnabled: false,
        intensity: .medium,
        isLookUpEnabled: false,
        isPrecisionScrollEnabled: true
      )

      store.save(configuration)

      try expectEqual(
        store.load(),
        configuration,
        "saved configuration should load unchanged"
      )
    }
  },

  TestCase(
    behavior: "given an unknown intensity raw value when loading then it falls back to default"
  ) {
    try withIsolatedDefaults { defaults in
      defaults.set(99, forKey: "intensity")
      let store = AppConfigurationStore(defaults: defaults)

      try expectEqual(
        store.load().intensity,
        AppConfiguration.defaultValue.intensity,
        "invalid stored intensity should fall back to default"
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
