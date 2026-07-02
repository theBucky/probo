import Observation
import Testing

@testable import ProboCore

@Suite("Probo runtime", .serialized)
struct ProboRuntimeTests {
  @MainActor
  @Test("missing accessibility keeps tap inactive at start")
  func missingAccessibilityAtStart() {
    let driver = ProboRuntimeDriver(
      configuration: AppConfiguration(),
      accessibilityTrusted: false
    )
    let runtime = ProboRuntime(environment: driver.environment)

    runtime.refreshAccessibility()

    #expect(runtime.statusSymbolName == "exclamationmark.triangle.fill")
    #expect(driver.eventTapActiveStates == [false])
    #expect(driver.frontmostActiveStates == [false])
  }

  @MainActor
  @Test("granting accessibility after start enables tap")
  func grantingAccessibilityAfterStart() {
    let driver = ProboRuntimeDriver(
      configuration: AppConfiguration(),
      accessibilityTrusted: false
    )
    let runtime = ProboRuntime(environment: driver.environment)
    runtime.refreshAccessibility()

    driver.accessibilityTrusted = true
    runtime.refreshAccessibility()
    driver.publishTapEnabled(true)

    #expect(runtime.statusSymbolName == "computermouse.fill")
    #expect(driver.eventTapActiveStates == [false, true])
    #expect(driver.frontmostActiveStates == [false, true])
  }

  @MainActor
  @Test("enabling without accessibility requests access")
  func enablingWithoutAccessibility() {
    var configuration = AppConfiguration()
    configuration.isEnabled = false
    let driver = ProboRuntimeDriver(
      configuration: configuration,
      accessibilityTrusted: false
    )
    let runtime = ProboRuntime(environment: driver.environment)
    runtime.refreshAccessibility()

    runtime.isEnabled = true

    #expect(driver.accessibilityPrompts == [false, true])
    #expect(driver.savedConfigurations.last?.isEnabled == true)
  }

  // Locks the settings UI contract: SwiftUI shows live toggle state only if
  // configuration reads are observation-tracked.
  @MainActor
  @Test("toggle changes notify observation trackers")
  func toggleChangesNotifyObservationTrackers() async {
    let driver = ProboRuntimeDriver(
      configuration: AppConfiguration(),
      accessibilityTrusted: true
    )
    let runtime = ProboRuntime(environment: driver.environment)

    await confirmation { changed in
      withObservationTracking {
        _ = runtime[toggle: \.isLookUpEnabled]
      } onChange: {
        changed()
      }
      runtime[toggle: \.isLookUpEnabled] = false
    }
  }

  @MainActor
  @Test("disabling runtime stops configured sleep prevention")
  func disablingRuntimeStopsSleepPrevention() {
    var configuration = AppConfiguration()
    configuration.preventsAutomaticSleep = true
    let driver = ProboRuntimeDriver(
      configuration: configuration,
      accessibilityTrusted: true
    )
    let runtime = ProboRuntime(environment: driver.environment)
    runtime.refreshAccessibility()

    runtime.isEnabled = false

    #expect(driver.sleepPreventionStates == [true, false])
    #expect(driver.eventTapActiveStates == [true, false])
  }
}

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
