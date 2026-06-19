import AppKit
import Testing

@testable import ProboCore

@Suite("Probo settings view controller", .serialized)
struct ProboSettingsViewControllerTests {
  @MainActor
  @Test("opening settings reflects runtime state")
  func openingSettingsReflectsRuntimeState() throws {
    _ = NSApplication.shared
    var configuration = AppConfiguration()
    configuration.intensity = .medium
    configuration.isOptionPrecisionEnabled = true
    configuration.isTerminalOptimizationEnabled = false
    configuration.isTrackpadStyleScrollingEnabled = true
    configuration.isLookUpEnabled = false
    configuration.preventsAutomaticSleep = true

    let driver = SettingsRuntimeDriver(
      configuration: configuration,
      accessibilityTrusted: false
    )
    let runtime = ProboRuntime(environment: driver.environment)
    runtime.refreshAccessibility()

    let controller = ProboSettingsViewController(runtime: runtime)
    controller.loadView()

    #expect(try popup("wheel-step", in: controller.view).selectedItem?.title == "Medium")
    let toggleExpectations: [(identifier: String, state: NSControl.StateValue, title: String)] = [
      ("option-precision", .on, "Option Precision"),
      ("terminal-optimization", .off, "Terminal Optimization"),
      ("natural-direction", .on, "Natural Direction"),
      ("look-up", .off, "Look Up"),
      ("prevent-automatic-sleep", .on, "Prevent Automatic Sleep"),
    ]

    for expectation in toggleExpectations {
      let toggle = try button(expectation.identifier, in: controller.view)
      #expect(toggle.state == expectation.state)
      #expect(toggle.accessibilityLabel() == expectation.title)
    }
    #expect(try label("accessibility-permission", in: controller.view).stringValue == "Required")
    _ = try #require(findSubview(identifier: "request-access", in: controller.view) as NSButton?)
  }

  @MainActor
  @Test("user changes persist runtime configuration")
  func userChangesPersistRuntimeConfiguration() throws {
    _ = NSApplication.shared
    let driver = SettingsRuntimeDriver(
      configuration: AppConfiguration(),
      accessibilityTrusted: true
    )
    let runtime = ProboRuntime(environment: driver.environment)
    runtime.refreshAccessibility()

    let controller = ProboSettingsViewController(runtime: runtime)
    controller.loadView()

    let wheelStep = try popup("wheel-step", in: controller.view)
    wheelStep.selectItem(withTitle: "Medium")
    _ = NSApp.sendAction(wheelStep.action!, to: wheelStep.target, from: wheelStep)

    #expect(driver.savedConfigurations.last?.intensity == .medium)

    let optionPrecision = try button("option-precision", in: controller.view)
    optionPrecision.state = .on
    _ = NSApp.sendAction(optionPrecision.action!, to: optionPrecision.target, from: optionPrecision)

    #expect(driver.savedConfigurations.last?.isOptionPrecisionEnabled == true)
  }

  @MainActor
  @Test("granted accessibility removes request access button")
  func grantedAccessibilityRemovesRequestAccessButton() throws {
    _ = NSApplication.shared
    let driver = SettingsRuntimeDriver(
      configuration: AppConfiguration(),
      accessibilityTrusted: false
    )
    let runtime = ProboRuntime(environment: driver.environment)
    runtime.refreshAccessibility()

    let controller = ProboSettingsViewController(runtime: runtime)
    controller.loadView()

    driver.accessibilityTrusted = true
    runtime.refreshAccessibility()
    controller.reload()

    #expect(try label("accessibility-permission", in: controller.view).stringValue == "Granted")
    #expect((findSubview(identifier: "request-access", in: controller.view) as NSButton?) == nil)
  }

  @MainActor
  @Test("settings reload keeps window frame fixed")
  func settingsReloadKeepsWindowFrameFixed() {
    _ = NSApplication.shared
    let driver = SettingsRuntimeDriver(
      configuration: AppConfiguration(),
      accessibilityTrusted: false
    )
    let runtime = ProboRuntime(environment: driver.environment)
    runtime.refreshAccessibility()

    let controller = ProboSettingsViewController(runtime: runtime)
    let window = NSWindow(contentViewController: controller)
    let frame = NSRect(x: 120, y: 160, width: 420, height: 320)
    window.setFrame(frame, display: false)

    driver.accessibilityTrusted = true
    runtime.refreshAccessibility()
    controller.reload()

    #expect(window.frame == frame)
  }
}

@MainActor
private final class SettingsRuntimeDriver {
  var accessibilityTrusted: Bool
  private(set) var savedConfigurations: [AppConfiguration] = []

  private let configuration: AppConfiguration

  var environment: ProboRuntimeEnvironment {
    ProboRuntimeEnvironment(
      loadConfiguration: { self.configuration },
      saveConfiguration: { self.savedConfigurations.append($0) },
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

@MainActor
private func button(_ identifier: String, in view: NSView) throws -> NSButton {
  try #require(findSubview(identifier: identifier, in: view) as NSButton?)
}

@MainActor
private func popup(_ identifier: String, in view: NSView) throws -> NSPopUpButton {
  try #require(findSubview(identifier: identifier, in: view) as NSPopUpButton?)
}

@MainActor
private func label(_ identifier: String, in view: NSView) throws -> NSTextField {
  try #require(findSubview(identifier: identifier, in: view) as NSTextField?)
}

@MainActor
private func findSubview<T: NSView>(identifier: String, in view: NSView) -> T? {
  if view.identifier?.rawValue == identifier {
    return view as? T
  }

  for subview in view.subviews {
    if let match: T = findSubview(identifier: identifier, in: subview) {
      return match
    }
  }

  return nil
}
