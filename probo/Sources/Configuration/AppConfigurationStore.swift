import Foundation

struct AppConfigurationStore {
  private static let configurationKey = "configuration"

  private let defaults: UserDefaults

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
  }

  func load() -> AppConfiguration {
    guard let data = defaults.data(forKey: Self.configurationKey) else { return .defaultValue }
    return (try? PropertyListDecoder().decode(AppConfiguration.self, from: data)) ?? .defaultValue
  }

  func save(_ configuration: AppConfiguration) {
    guard let data = try? PropertyListEncoder().encode(configuration) else { return }
    defaults.set(data, forKey: Self.configurationKey)
  }
}
