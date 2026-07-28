import Foundation

struct IsolatedDefaults: ~Copyable {
  let defaults: UserDefaults
  private let suiteName: String

  init() {
    suiteName = "com.probo.tests.\(UUID().uuidString)"
    defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)
  }

  deinit {
    defaults.removePersistentDomain(forName: suiteName)
  }
}
