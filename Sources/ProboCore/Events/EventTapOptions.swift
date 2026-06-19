// Atomic-friendly configuration snapshot for the tap callback. Backed by a raw
// bit field so the hot path stores/loads one UInt32 and reads only the bits it needs.
package struct EventTapOptions: Sendable {
  private static let lookUpBit: UInt32 = 1 << 0
  private static let optionPrecisionBit: UInt32 = 1 << 1
  private static let terminalOptimizationBit: UInt32 = 1 << 2
  private static let trackpadStyleScrollingBit: UInt32 = 1 << 3
  private static let mediumIntensityBit: UInt32 = 1 << 4

  package let rawValue: UInt32

  package init(rawValue: UInt32) {
    self.rawValue = rawValue
  }

  package init(configuration: AppConfiguration) {
    var value: UInt32 = 0
    if configuration.isLookUpEnabled { value |= Self.lookUpBit }
    if configuration.isOptionPrecisionEnabled { value |= Self.optionPrecisionBit }
    if configuration.isTerminalOptimizationEnabled { value |= Self.terminalOptimizationBit }
    if configuration.isTrackpadStyleScrollingEnabled { value |= Self.trackpadStyleScrollingBit }
    if configuration.intensity == .medium { value |= Self.mediumIntensityBit }
    rawValue = value
  }

  package var isLookUpEnabled: Bool { rawValue & Self.lookUpBit != 0 }
  package var isOptionPrecisionEnabled: Bool { rawValue & Self.optionPrecisionBit != 0 }
  package var isTerminalOptimizationEnabled: Bool { rawValue & Self.terminalOptimizationBit != 0 }
  package var isTrackpadStyleScrollingEnabled: Bool {
    rawValue & Self.trackpadStyleScrollingBit != 0
  }
  package var intensity: ScrollIntensity {
    rawValue & Self.mediumIntensityBit == 0 ? .slow : .medium
  }
}
