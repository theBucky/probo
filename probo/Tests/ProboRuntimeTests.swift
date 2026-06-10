let proboRuntimeTests: [TestCase] = [
  TestCase(
    behavior: "given accessibility is missing when runtime starts then tap stays inactive"
  ) {
    let driver = ProboRuntimeDriver(
      configuration: .defaultValue,
      accessibilityTrusted: false
    )
    let runtime = ProboRuntime(environment: driver.environment)

    runtime.start()

    try expectEqual(
      runtime.statusSymbolName, "exclamationmark.triangle.fill",
      "enabled runtime should surface missing accessibility")
    try expectEqual(
      driver.eventTapActiveStates, [false], "runtime should not enable tap without accessibility")
    try expectEqual(
      driver.frontmostActiveStates, [false],
      "runtime should not monitor frontmost app without tap access")
  },

  TestCase(
    behavior: "given accessibility is granted after start then runtime enables tap"
  ) {
    let driver = ProboRuntimeDriver(
      configuration: .defaultValue,
      accessibilityTrusted: false
    )
    let runtime = ProboRuntime(environment: driver.environment)
    runtime.start()

    driver.accessibilityTrusted = true
    runtime.refreshSystemState()
    driver.publishTapEnabled(true)

    try expectEqual(
      runtime.statusSymbolName, "computermouse.fill",
      "trusted active runtime should show active icon")
    try expectEqual(
      driver.eventTapActiveStates, [false, true],
      "runtime should enable tap after accessibility is trusted")
    try expectEqual(
      driver.frontmostActiveStates, [false, true],
      "runtime should monitor frontmost apps when terminal optimization is active")
  },

  TestCase(
    behavior: "given enabled is turned on without accessibility then runtime requests access"
  ) {
    var configuration = AppConfiguration.defaultValue
    configuration.isEnabled = false
    let driver = ProboRuntimeDriver(
      configuration: configuration,
      accessibilityTrusted: false
    )
    let runtime = ProboRuntime(environment: driver.environment)
    runtime.start()

    runtime.isEnabled = true

    try expectEqual(
      driver.accessibilityPrompts, [false, true], "enabling without trust should prompt once")
    try expectEqual(
      driver.savedConfigurations.last?.isEnabled, true, "enabled change should persist")
  },

  TestCase(
    behavior:
      "given sleep prevention is configured when runtime is disabled then sleep prevention stops"
  ) {
    var configuration = AppConfiguration.defaultValue
    configuration.preventsAutomaticSleep = true
    let driver = ProboRuntimeDriver(
      configuration: configuration,
      accessibilityTrusted: true
    )
    let runtime = ProboRuntime(environment: driver.environment)
    runtime.start()

    runtime.isEnabled = false

    try expectEqual(
      driver.sleepPreventionStates, [true, false], "disabling runtime should stop sleep prevention")
    try expectEqual(
      driver.eventTapActiveStates, [true, false], "disabling runtime should stop event tap")
  },
]

@MainActor
private final class ProboRuntimeDriver {
  var accessibilityTrusted: Bool
  private(set) var accessibilityPrompts: [Bool] = []
  private(set) var savedConfigurations: [AppConfiguration] = []
  private(set) var frontmostActiveStates: [Bool] = []
  private(set) var eventTapActiveStates: [Bool] = []
  private(set) var sleepPreventionStates: [Bool] = []

  private let configuration: AppConfiguration
  private var tapEnabledHandler: (@MainActor (Bool) -> Void)?

  var environment: ProboRuntimeEnvironment {
    ProboRuntimeEnvironment(
      loadConfiguration: { self.configuration },
      saveConfiguration: { self.savedConfigurations.append($0) },
      isAccessibilityTrusted: {
        self.accessibilityPrompts.append($0)
        return self.accessibilityTrusted
      },
      isStartAtLoginEnabled: { false },
      setStartAtLoginEnabled: { _ in },
      setFrontmostMonitorActive: { self.frontmostActiveStates.append($0) },
      setTapEnabledHandler: { self.tapEnabledHandler = $0 },
      setEventTapConfiguration: { _ in },
      setEventTapActive: { self.eventTapActiveStates.append($0) },
      setAutomaticSleepPreventionEnabled: { self.sleepPreventionStates.append($0) },
      makeAccessibilityGrantTask: { _ in Task {} }
    )
  }

  init(configuration: AppConfiguration, accessibilityTrusted: Bool) {
    self.configuration = configuration
    self.accessibilityTrusted = accessibilityTrusted
  }

  func publishTapEnabled(_ enabled: Bool) {
    tapEnabledHandler?(enabled)
  }
}
