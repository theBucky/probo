import AppKit
import Testing

@testable import ProboCore

@Suite("Probo settings view controller", .serialized)
struct ProboSettingsViewControllerTests {
  @MainActor
  @Test("accessibility change keeps window frame fixed")
  func accessibilityChangeKeepsWindowFrameFixed() {
    _ = NSApplication.shared
    let driver = SettingsRuntimeDriver(
      configuration: AppConfiguration(),
      accessibilityTrusted: false
    )
    let runtime = ProboRuntime(environment: driver.environment)
    runtime.refreshAccessibility()

    let controller = ProboSettingsViewController(runtime: runtime)
    let window = NSWindow(contentViewController: controller)
    let frame = NSRect(x: 120, y: 160, width: 500, height: 430)
    window.setFrame(frame, display: false)

    driver.accessibilityTrusted = true
    runtime.refreshAccessibility()

    #expect(window.frame == frame)
  }
}

@MainActor
private final class SettingsRuntimeDriver {
  var accessibilityTrusted: Bool
  private let configuration: AppConfiguration

  var environment: ProboRuntimeEnvironment {
    ProboRuntimeEnvironment(
      loadConfiguration: { self.configuration },
      saveConfiguration: { _ in },
      isAccessibilityTrusted: { _ in self.accessibilityTrusted },
      isStartAtLoginEnabled: { false },
      setStartAtLoginEnabled: { _ in },
      setFrontmostMonitorActive: { _ in },
      setTapEnabledHandler: { _ in },
      setEventTapConfiguration: { _ in },
      setEventTapActive: { _ in },
      setAutomaticSleepPreventionEnabled: { _ in },
      makeAccessibilityGrantTask: { _ in Task {} }
    )
  }

  init(configuration: AppConfiguration, accessibilityTrusted: Bool) {
    self.configuration = configuration
    self.accessibilityTrusted = accessibilityTrusted
  }
}
