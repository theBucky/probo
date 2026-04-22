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
        let isEnabled = defaults.bool(forKey: Key.isEnabled)
        let rawIntensity = defaults.integer(forKey: Key.intensity)
        let intensity = ScrollIntensity(rawValue: rawIntensity) ?? .slow
        return AppConfiguration(isEnabled: isEnabled, intensity: intensity)
    }

    func save(_ configuration: AppConfiguration) {
        defaults.set(configuration.isEnabled, forKey: Key.isEnabled)
        defaults.set(configuration.intensity.rawValue, forKey: Key.intensity)
    }
}
