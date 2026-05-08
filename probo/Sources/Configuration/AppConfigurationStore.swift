import Foundation

final class AppConfigurationStore {
  private enum Key {
    static let isEnabled = "isEnabled"
    static let intensity = "intensity"
    static let isLookUpEnabled = "isLookUpEnabled"
    static let isPrecisionScrollEnabled = "isPrecisionScrollEnabled"
    static let isTerminalPrecisionEnabled = "isTerminalPrecisionEnabled"
    static let isTrackpadStyleScrollingEnabled = "isTrackpadStyleScrollingEnabled"
  }

  private let defaults: UserDefaults

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    defaults.register(defaults: [
      Key.isEnabled: AppConfiguration.defaultValue.isEnabled,
      Key.intensity: AppConfiguration.defaultValue.intensity.rawValue,
      Key.isLookUpEnabled: AppConfiguration.defaultValue.isLookUpEnabled,
      Key.isPrecisionScrollEnabled: AppConfiguration.defaultValue.isPrecisionScrollEnabled,
      Key.isTerminalPrecisionEnabled: AppConfiguration.defaultValue.isTerminalPrecisionEnabled,
      Key.isTrackpadStyleScrollingEnabled:
        AppConfiguration.defaultValue.isTrackpadStyleScrollingEnabled,
    ])
  }

  func load() -> AppConfiguration {
    AppConfiguration(
      isEnabled: defaults.bool(forKey: Key.isEnabled),
      intensity: ScrollIntensity(rawValue: defaults.integer(forKey: Key.intensity))
        ?? AppConfiguration.defaultValue.intensity,
      isLookUpEnabled: defaults.bool(forKey: Key.isLookUpEnabled),
      isPrecisionScrollEnabled: defaults.bool(forKey: Key.isPrecisionScrollEnabled),
      isTerminalPrecisionEnabled: defaults.bool(forKey: Key.isTerminalPrecisionEnabled),
      isTrackpadStyleScrollingEnabled: defaults.bool(forKey: Key.isTrackpadStyleScrollingEnabled)
    )
  }

  func save(_ configuration: AppConfiguration) {
    defaults.set(configuration.isEnabled, forKey: Key.isEnabled)
    defaults.set(configuration.intensity.rawValue, forKey: Key.intensity)
    defaults.set(configuration.isLookUpEnabled, forKey: Key.isLookUpEnabled)
    defaults.set(configuration.isPrecisionScrollEnabled, forKey: Key.isPrecisionScrollEnabled)
    defaults.set(configuration.isTerminalPrecisionEnabled, forKey: Key.isTerminalPrecisionEnabled)
    defaults.set(
      configuration.isTrackpadStyleScrollingEnabled,
      forKey: Key.isTrackpadStyleScrollingEnabled
    )
  }
}
