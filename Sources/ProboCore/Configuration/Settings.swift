import Foundation

package struct AppConfiguration: Equatable, Sendable {
  package var isEnabled: Bool
  package var wheelStep: WheelStep
  package var isLookUpEnabled: Bool
  package var isOptionPrecisionEnabled: Bool
  package var isTerminalOptimizationEnabled: Bool
  package var isTrackpadStyleScrollingEnabled: Bool
  package var preventsIdleSleep: Bool

  package init(
    isEnabled: Bool = true,
    wheelStep: WheelStep = .slow,
    isLookUpEnabled: Bool = true,
    isOptionPrecisionEnabled: Bool = false,
    isTerminalOptimizationEnabled: Bool = true,
    isTrackpadStyleScrollingEnabled: Bool = false,
    preventsIdleSleep: Bool = false
  ) {
    self.isEnabled = isEnabled
    self.wheelStep = wheelStep
    self.isLookUpEnabled = isLookUpEnabled
    self.isOptionPrecisionEnabled = isOptionPrecisionEnabled
    self.isTerminalOptimizationEnabled = isTerminalOptimizationEnabled
    self.isTrackpadStyleScrollingEnabled = isTrackpadStyleScrollingEnabled
    self.preventsIdleSleep = preventsIdleSleep
  }
}

extension TapOptions {
  package init(configuration: AppConfiguration) {
    self.init(
      isLookUpEnabled: configuration.isLookUpEnabled,
      isOptionPrecisionEnabled: configuration.isOptionPrecisionEnabled,
      isTerminalOptimizationEnabled: configuration.isTerminalOptimizationEnabled,
      isTrackpadStyleScrollingEnabled: configuration.isTrackpadStyleScrollingEnabled,
      stepLines: configuration.wheelStep.lines
    )
  }
}

package struct SettingsStore {
  private static let wheelStepKey = "wheelStep"
  private static let boolFields:
    [(key: String, path: WritableKeyPath<AppConfiguration, Bool> & Sendable)] = [
      ("isEnabled", \.isEnabled),
      ("isLookUpEnabled", \.isLookUpEnabled),
      ("isOptionPrecisionEnabled", \.isOptionPrecisionEnabled),
      ("isTerminalOptimizationEnabled", \.isTerminalOptimizationEnabled),
      ("isTrackpadStyleScrollingEnabled", \.isTrackpadStyleScrollingEnabled),
      ("preventsIdleSleep", \.preventsIdleSleep),
    ]

  private let defaults: UserDefaults

  package init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    let fallback = AppConfiguration()
    var registration: [String: Any] = [Self.wheelStepKey: fallback.wheelStep.rawValue]
    for (key, path) in Self.boolFields {
      registration[key] = fallback[keyPath: path]
    }
    defaults.register(defaults: registration)
  }

  package func load() -> AppConfiguration {
    var configuration = AppConfiguration(
      wheelStep: WheelStep(rawValue: defaults.integer(forKey: Self.wheelStepKey)) ?? .slow
    )
    for (key, path) in Self.boolFields {
      configuration[keyPath: path] = defaults.bool(forKey: key)
    }
    return configuration
  }

  package func save(_ configuration: AppConfiguration) {
    defaults.set(configuration.wheelStep.rawValue, forKey: Self.wheelStepKey)
    for (key, path) in Self.boolFields {
      defaults.set(configuration[keyPath: path], forKey: key)
    }
  }
}
