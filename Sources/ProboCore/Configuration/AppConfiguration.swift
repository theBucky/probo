package struct AppConfiguration: Equatable, Codable, Sendable {
  package var isEnabled: Bool
  package var intensity: ScrollIntensity
  package var isLookUpEnabled: Bool
  package var isOptionPrecisionEnabled: Bool
  package var isTerminalOptimizationEnabled: Bool
  package var isTrackpadStyleScrollingEnabled: Bool
  package var preventsAutomaticSleep: Bool

  package init(
    isEnabled: Bool = true,
    intensity: ScrollIntensity = .slow,
    isLookUpEnabled: Bool = true,
    isOptionPrecisionEnabled: Bool = false,
    isTerminalOptimizationEnabled: Bool = true,
    isTrackpadStyleScrollingEnabled: Bool = false,
    preventsAutomaticSleep: Bool = false
  ) {
    self.isEnabled = isEnabled
    self.intensity = intensity
    self.isLookUpEnabled = isLookUpEnabled
    self.isOptionPrecisionEnabled = isOptionPrecisionEnabled
    self.isTerminalOptimizationEnabled = isTerminalOptimizationEnabled
    self.isTrackpadStyleScrollingEnabled = isTrackpadStyleScrollingEnabled
    self.preventsAutomaticSleep = preventsAutomaticSleep
  }
}

extension AppConfiguration {
  // Start from defaults, then overlay each field that decodes cleanly, so a partial or
  // schema-evolved record keeps its valid values instead of resetting everything.
  package init(from decoder: Decoder) throws {
    self.init()
    let container = try decoder.container(keyedBy: CodingKeys.self)
    isEnabled = container.value(.isEnabled, fallback: isEnabled)
    intensity = container.value(.intensity, fallback: intensity)
    isLookUpEnabled = container.value(.isLookUpEnabled, fallback: isLookUpEnabled)
    isOptionPrecisionEnabled = container.value(
      .isOptionPrecisionEnabled, fallback: isOptionPrecisionEnabled)
    isTerminalOptimizationEnabled = container.value(
      .isTerminalOptimizationEnabled, fallback: isTerminalOptimizationEnabled)
    isTrackpadStyleScrollingEnabled = container.value(
      .isTrackpadStyleScrollingEnabled, fallback: isTrackpadStyleScrollingEnabled)
    preventsAutomaticSleep = container.value(
      .preventsAutomaticSleep, fallback: preventsAutomaticSleep)
  }
}

extension KeyedDecodingContainer {
  fileprivate func value<T: Decodable>(_ key: Key, fallback: T) -> T {
    (try? decode(T.self, forKey: key)) ?? fallback
  }
}
