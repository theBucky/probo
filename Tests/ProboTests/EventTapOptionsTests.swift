import Testing

@testable import ProboCore

@Suite("Event tap options")
struct EventTapOptionsTests {
  @Test("configuration packs into hot-path options")
  func configurationMapping() {
    let configuration = AppConfiguration(
      intensity: .medium,
      isLookUpEnabled: false,
      isOptionPrecisionEnabled: true,
      isTerminalOptimizationEnabled: false,
      isTrackpadStyleScrollingEnabled: true
    )

    let options = EventTapOptions(configuration: configuration)

    #expect(options.intensity == .medium)
    #expect(options.isLookUpEnabled == false)
    #expect(options.isOptionPrecisionEnabled == true)
    #expect(options.isTerminalOptimizationEnabled == false)
    #expect(options.isTrackpadStyleScrollingEnabled == true)
  }
}
