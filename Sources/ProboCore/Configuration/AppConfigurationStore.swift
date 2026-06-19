import Foundation

struct AppConfigurationStore {
  private static let configurationKey = "configuration"

  private let defaults: UserDefaults

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
  }

  func load() -> AppConfiguration {
    guard let data = defaults.data(forKey: Self.configurationKey) else { return AppConfiguration() }
    return (try? PropertyListDecoder().decode(AppConfiguration.self, from: data))
      ?? AppConfiguration()
  }

  func save(_ configuration: AppConfiguration) {
    let data = try! PropertyListEncoder().encode(configuration)
    defaults.set(data, forKey: Self.configurationKey)
  }
}
