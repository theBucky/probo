import Foundation

final class AppConfigurationStore {
  private enum Key {
    static let isEnabled = "isEnabled"
    static let intensity = "intensity"
    static let stepMode = "stepMode"
    static let isLookUpEnabled = "isLookUpEnabled"
    static let isPrecisionScrollEnabled = "isPrecisionScrollEnabled"
  }

  private let defaults: UserDefaults

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    defaults.register(defaults: [
      Key.isEnabled: AppConfiguration.defaultValue.isEnabled,
      Key.intensity: AppConfiguration.defaultValue.intensity.rawValue,
      Key.stepMode: AppConfiguration.defaultValue.stepMode.rawValue,
      Key.isLookUpEnabled: AppConfiguration.defaultValue.isLookUpEnabled,
      Key.isPrecisionScrollEnabled: AppConfiguration.defaultValue.isPrecisionScrollEnabled,
    ])
  }

  func load() -> AppConfiguration {
    AppConfiguration(
      isEnabled: defaults.bool(forKey: Key.isEnabled),
      intensity: ScrollIntensity(rawValue: defaults.integer(forKey: Key.intensity))
        ?? AppConfiguration.defaultValue.intensity,
      stepMode: ScrollStepMode(rawValue: defaults.integer(forKey: Key.stepMode))
        ?? AppConfiguration.defaultValue.stepMode,
      isLookUpEnabled: defaults.bool(forKey: Key.isLookUpEnabled),
      isPrecisionScrollEnabled: defaults.bool(forKey: Key.isPrecisionScrollEnabled)
    )
  }

  func save(_ configuration: AppConfiguration) {
    defaults.set(configuration.isEnabled, forKey: Key.isEnabled)
    defaults.set(configuration.intensity.rawValue, forKey: Key.intensity)
    defaults.set(configuration.stepMode.rawValue, forKey: Key.stepMode)
    defaults.set(configuration.isLookUpEnabled, forKey: Key.isLookUpEnabled)
    defaults.set(configuration.isPrecisionScrollEnabled, forKey: Key.isPrecisionScrollEnabled)
  }
}
