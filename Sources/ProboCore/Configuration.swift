import Foundation
import Synchronization

package enum WheelStep: Int, CaseIterable, Sendable {
  case slow = 0
  case medium = 1

  package var lines: Int32 {
    switch self {
    case .slow: 2
    case .medium: 3
    }
  }
}

package struct InputConfiguration: Equatable, Sendable {
  package var wheelStep: WheelStep
  package var isLookUpEnabled: Bool
  package var isOptionPrecisionEnabled: Bool
  package var isTerminalOptimizationEnabled: Bool
  package var isTrackpadStyleScrollingEnabled: Bool

  package init(
    wheelStep: WheelStep = .slow,
    isLookUpEnabled: Bool = true,
    isOptionPrecisionEnabled: Bool = false,
    isTerminalOptimizationEnabled: Bool = true,
    isTrackpadStyleScrollingEnabled: Bool = false
  ) {
    self.wheelStep = wheelStep
    self.isLookUpEnabled = isLookUpEnabled
    self.isOptionPrecisionEnabled = isOptionPrecisionEnabled
    self.isTerminalOptimizationEnabled = isTerminalOptimizationEnabled
    self.isTrackpadStyleScrollingEnabled = isTrackpadStyleScrollingEnabled
  }
}

// One 32-bit word so the tap thread loads a coherent snapshot without a lock.
extension InputConfiguration: AtomicRepresentable {
  package typealias AtomicRepresentation = UInt32.AtomicRepresentation

  private static let lookUpBit: UInt32 = 1 << 0
  private static let optionPrecisionBit: UInt32 = 1 << 1
  private static let terminalOptimizationBit: UInt32 = 1 << 2
  private static let trackpadStyleScrollingBit: UInt32 = 1 << 3
  private static let wheelStepShift: UInt32 = 8

  package static func encodeAtomicRepresentation(
    _ value: consuming InputConfiguration
  ) -> AtomicRepresentation {
    var bits = UInt32(value.wheelStep.rawValue) << wheelStepShift
    if value.isLookUpEnabled { bits |= lookUpBit }
    if value.isOptionPrecisionEnabled { bits |= optionPrecisionBit }
    if value.isTerminalOptimizationEnabled { bits |= terminalOptimizationBit }
    if value.isTrackpadStyleScrollingEnabled { bits |= trackpadStyleScrollingBit }
    return UInt32.encodeAtomicRepresentation(bits)
  }

  package static func decodeAtomicRepresentation(
    _ storage: consuming AtomicRepresentation
  ) -> InputConfiguration {
    let bits = UInt32.decodeAtomicRepresentation(storage)
    return InputConfiguration(
      wheelStep: WheelStep(rawValue: Int(bits >> wheelStepShift)) ?? .slow,
      isLookUpEnabled: bits & lookUpBit != 0,
      isOptionPrecisionEnabled: bits & optionPrecisionBit != 0,
      isTerminalOptimizationEnabled: bits & terminalOptimizationBit != 0,
      isTrackpadStyleScrollingEnabled: bits & trackpadStyleScrollingBit != 0
    )
  }
}

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

package struct ConfigurationStore {
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
