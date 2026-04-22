import Foundation

final class AppConfigurationStore {
    private enum Key {
        static let isEnabled = "isEnabled"
        static let intensity = "intensity"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            Key.isEnabled: true,
            Key.intensity: ScrollIntensity.slow.rawValue,
        ])
    }

    func load() -> AppConfiguration {
        AppConfiguration(
            isEnabled: defaults.bool(forKey: Key.isEnabled),
            intensity: ScrollIntensity(rawValue: defaults.integer(forKey: Key.intensity)) ?? .slow
        )
    }

    func save(_ configuration: AppConfiguration) {
        defaults.set(configuration.isEnabled, forKey: Key.isEnabled)
        defaults.set(configuration.intensity.rawValue, forKey: Key.intensity)
    }
}
