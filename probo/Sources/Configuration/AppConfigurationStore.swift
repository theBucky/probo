import Foundation

final class AppConfigurationStore {
  private enum Key {
    static let isEnabled = "isEnabled"
    static let intensity = "intensity"
    static let isLookUpEnabled = "isLookUpEnabled"
    static let isOptionPrecisionEnabled = "isOptionPrecisionEnabled"
    static let isTerminalDefaultPrecisionEnabled = "isTerminalDefaultPrecisionEnabled"
    static let isTrackpadStyleScrollingEnabled = "isTrackpadStyleScrollingEnabled"
    static let preventsAutomaticSleep = "preventsAutomaticSleep"
  }

  private let defaults: UserDefaults

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    let configuration = AppConfiguration.defaultValue
    defaults.register(defaults: [
      Key.isEnabled: configuration.isEnabled,
      Key.intensity: configuration.intensity.rawValue,
      Key.isLookUpEnabled: configuration.isLookUpEnabled,
      Key.isOptionPrecisionEnabled: configuration.isOptionPrecisionEnabled,
      Key.isTerminalDefaultPrecisionEnabled: configuration.isTerminalDefaultPrecisionEnabled,
      Key.isTrackpadStyleScrollingEnabled: configuration.isTrackpadStyleScrollingEnabled,
      Key.preventsAutomaticSleep: configuration.preventsAutomaticSleep,
    ])
  }

  func load() -> AppConfiguration {
    AppConfiguration(
      isEnabled: defaults.bool(forKey: Key.isEnabled),
      intensity: ScrollIntensity(rawValue: defaults.integer(forKey: Key.intensity))
        ?? AppConfiguration.defaultValue.intensity,
      isLookUpEnabled: defaults.bool(forKey: Key.isLookUpEnabled),
      isOptionPrecisionEnabled: defaults.bool(forKey: Key.isOptionPrecisionEnabled),
      isTerminalDefaultPrecisionEnabled: defaults.bool(
        forKey: Key.isTerminalDefaultPrecisionEnabled),
      isTrackpadStyleScrollingEnabled: defaults.bool(forKey: Key.isTrackpadStyleScrollingEnabled),
      preventsAutomaticSleep: defaults.bool(forKey: Key.preventsAutomaticSleep)
    )
  }

  func save(_ configuration: AppConfiguration) {
    defaults.set(configuration.isEnabled, forKey: Key.isEnabled)
    defaults.set(configuration.intensity.rawValue, forKey: Key.intensity)
    defaults.set(configuration.isLookUpEnabled, forKey: Key.isLookUpEnabled)
    defaults.set(configuration.isOptionPrecisionEnabled, forKey: Key.isOptionPrecisionEnabled)
    defaults.set(
      configuration.isTerminalDefaultPrecisionEnabled, forKey: Key.isTerminalDefaultPrecisionEnabled
    )
    defaults.set(
      configuration.isTrackpadStyleScrollingEnabled,
      forKey: Key.isTrackpadStyleScrollingEnabled
    )
    defaults.set(configuration.preventsAutomaticSleep, forKey: Key.preventsAutomaticSleep)
  }
}
