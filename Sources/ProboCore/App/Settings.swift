import Foundation

package struct AppConfiguration: Equatable, Sendable {
  package var isEnabled: Bool
  package var input: InputConfiguration
  package var preventsIdleSleep: Bool

  package init(
    isEnabled: Bool = true,
    input: InputConfiguration = InputConfiguration(),
    preventsIdleSleep: Bool = false
  ) {
    self.isEnabled = isEnabled
    self.input = input
    self.preventsIdleSleep = preventsIdleSleep
  }
}

package struct SettingsStore {
  private enum Key {
    static let isEnabled = "isEnabled"
    static let wheelStep = "wheelStep"
    static let isLookUpEnabled = "isLookUpEnabled"
    static let isOptionPrecisionEnabled = "isOptionPrecisionEnabled"
    static let isTerminalOptimizationEnabled = "isTerminalOptimizationEnabled"
    static let isTrackpadStyleScrollingEnabled = "isTrackpadStyleScrollingEnabled"
    static let preventsIdleSleep = "preventsIdleSleep"
  }

  private let defaults: UserDefaults

  package init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    let fallback = AppConfiguration()
    defaults.register(defaults: [
      Key.isEnabled: fallback.isEnabled,
      Key.wheelStep: fallback.input.wheelStep.rawValue,
      Key.isLookUpEnabled: fallback.input.isLookUpEnabled,
      Key.isOptionPrecisionEnabled: fallback.input.isOptionPrecisionEnabled,
      Key.isTerminalOptimizationEnabled: fallback.input.isTerminalOptimizationEnabled,
      Key.isTrackpadStyleScrollingEnabled: fallback.input.isTrackpadStyleScrollingEnabled,
      Key.preventsIdleSleep: fallback.preventsIdleSleep,
    ])
  }

  package func load() -> AppConfiguration {
    AppConfiguration(
      isEnabled: defaults.bool(forKey: Key.isEnabled),
      input: InputConfiguration(
        wheelStep: WheelStep(rawValue: defaults.integer(forKey: Key.wheelStep)) ?? .slow,
        isLookUpEnabled: defaults.bool(forKey: Key.isLookUpEnabled),
        isOptionPrecisionEnabled: defaults.bool(forKey: Key.isOptionPrecisionEnabled),
        isTerminalOptimizationEnabled: defaults.bool(forKey: Key.isTerminalOptimizationEnabled),
        isTrackpadStyleScrollingEnabled: defaults.bool(
          forKey: Key.isTrackpadStyleScrollingEnabled
        )
      ),
      preventsIdleSleep: defaults.bool(forKey: Key.preventsIdleSleep)
    )
  }

  package func save(_ configuration: AppConfiguration) {
    defaults.set(configuration.isEnabled, forKey: Key.isEnabled)
    defaults.set(configuration.input.wheelStep.rawValue, forKey: Key.wheelStep)
    defaults.set(configuration.input.isLookUpEnabled, forKey: Key.isLookUpEnabled)
    defaults.set(
      configuration.input.isOptionPrecisionEnabled,
      forKey: Key.isOptionPrecisionEnabled
    )
    defaults.set(
      configuration.input.isTerminalOptimizationEnabled,
      forKey: Key.isTerminalOptimizationEnabled
    )
    defaults.set(
      configuration.input.isTrackpadStyleScrollingEnabled,
      forKey: Key.isTrackpadStyleScrollingEnabled
    )
    defaults.set(configuration.preventsIdleSleep, forKey: Key.preventsIdleSleep)
  }
}
