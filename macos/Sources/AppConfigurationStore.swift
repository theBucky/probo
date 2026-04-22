import Foundation

final class AppConfigurationStore {
  private enum Key {
    static let isEnabled = "isEnabled"
    static let intensity = "intensity"
    static let isLookUpEnabled = "isLookUpEnabled"
  }

  private let defaults: UserDefaults

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    defaults.register(defaults: [
      Key.isEnabled: AppConfiguration.defaultValue.isEnabled,
      Key.intensity: AppConfiguration.defaultValue.intensity.rawValue,
      Key.isLookUpEnabled: AppConfiguration.defaultValue.isLookUpEnabled,
    ])
  }

  func load() -> AppConfiguration {
    AppConfiguration(
      isEnabled: defaults.bool(forKey: Key.isEnabled),
      intensity: ScrollIntensity(rawValue: defaults.integer(forKey: Key.intensity))
        ?? AppConfiguration.defaultValue.intensity,
      isLookUpEnabled: defaults.bool(forKey: Key.isLookUpEnabled)
    )
  }

  func save(_ configuration: AppConfiguration) {
    defaults.set(configuration.isEnabled, forKey: Key.isEnabled)
    defaults.set(configuration.intensity.rawValue, forKey: Key.intensity)
    defaults.set(configuration.isLookUpEnabled, forKey: Key.isLookUpEnabled)
  }
}
