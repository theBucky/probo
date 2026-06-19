package struct AppConfiguration: Equatable, Codable, Sendable {
  package var isEnabled = true
  package var intensity = ScrollIntensity.slow
  package var isLookUpEnabled = true
  package var isOptionPrecisionEnabled = false
  package var isTerminalOptimizationEnabled = true
  package var isTrackpadStyleScrollingEnabled = false
  package var preventsAutomaticSleep = false

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

  package init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    self.init(
      isEnabled: values.decode(.isEnabled, fallback: true),
      intensity: values.decode(.intensity, fallback: .slow),
      isLookUpEnabled: values.decode(.isLookUpEnabled, fallback: true),
      isOptionPrecisionEnabled: values.decode(.isOptionPrecisionEnabled, fallback: false),
      isTerminalOptimizationEnabled: values.decode(.isTerminalOptimizationEnabled, fallback: true),
      isTrackpadStyleScrollingEnabled: values.decode(
        .isTrackpadStyleScrollingEnabled, fallback: false),
      preventsAutomaticSleep: values.decode(.preventsAutomaticSleep, fallback: false)
    )
  }
}

extension KeyedDecodingContainer {
  fileprivate func decode<T: Decodable>(_ key: Key, fallback: T) -> T {
    (try? decode(T.self, forKey: key)) ?? fallback
  }
}
