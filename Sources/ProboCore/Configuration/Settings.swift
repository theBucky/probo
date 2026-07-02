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
    defaults.register(defaults: [
      Key.isEnabled: true,
      Key.wheelStep: WheelStep.slow.rawValue,
      Key.isLookUpEnabled: true,
      Key.isOptionPrecisionEnabled: false,
      Key.isTerminalOptimizationEnabled: true,
      Key.isTrackpadStyleScrollingEnabled: false,
      Key.preventsIdleSleep: false,
    ])
  }

  package func load() -> AppConfiguration {
    AppConfiguration(
      isEnabled: defaults.bool(forKey: Key.isEnabled),
      wheelStep: WheelStep(rawValue: defaults.integer(forKey: Key.wheelStep)) ?? .slow,
      isLookUpEnabled: defaults.bool(forKey: Key.isLookUpEnabled),
      isOptionPrecisionEnabled: defaults.bool(forKey: Key.isOptionPrecisionEnabled),
      isTerminalOptimizationEnabled: defaults.bool(forKey: Key.isTerminalOptimizationEnabled),
      isTrackpadStyleScrollingEnabled: defaults.bool(forKey: Key.isTrackpadStyleScrollingEnabled),
      preventsIdleSleep: defaults.bool(forKey: Key.preventsIdleSleep)
    )
  }

  package func save(_ configuration: AppConfiguration) {
    defaults.set(configuration.isEnabled, forKey: Key.isEnabled)
    defaults.set(configuration.wheelStep.rawValue, forKey: Key.wheelStep)
    defaults.set(configuration.isLookUpEnabled, forKey: Key.isLookUpEnabled)
    defaults.set(configuration.isOptionPrecisionEnabled, forKey: Key.isOptionPrecisionEnabled)
    defaults.set(
      configuration.isTerminalOptimizationEnabled, forKey: Key.isTerminalOptimizationEnabled)
    defaults.set(
      configuration.isTrackpadStyleScrollingEnabled, forKey: Key.isTrackpadStyleScrollingEnabled)
    defaults.set(configuration.preventsIdleSleep, forKey: Key.preventsIdleSleep)
  }
}
