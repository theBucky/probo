import AppKit

let proboSettingsViewControllerTests: [TestCase] = [
  TestCase(
    behavior: "given settings opens then controls reflect runtime state"
  ) {
    var configuration = AppConfiguration.defaultValue
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
    runtime.refreshSystemState()

    let controller = ProboSettingsViewController(runtime: runtime)
    controller.loadView()

    try expectEqual(
      try popup("wheel-step", in: controller.view).selectedItem?.title,
      "Medium",
      "wheel step popup should show current intensity")
    let toggleExpectations: [(identifier: String, state: NSControl.StateValue, title: String)] = [
      ("option-precision", .on, "Option Precision"),
      ("terminal-optimization", .off, "Terminal Optimization"),
      ("natural-direction", .on, "Natural Direction"),
      ("look-up", .off, "Look Up"),
      ("prevent-automatic-sleep", .on, "Prevent Automatic Sleep"),
    ]

    for expectation in toggleExpectations {
      let toggle = try button(expectation.identifier, in: controller.view)
      try expectEqual(
        toggle.state,
        expectation.state,
        "\(expectation.title) toggle should reflect configuration")
      try expectEqual(
        toggle.accessibilityLabel(),
        expectation.title,
        "\(expectation.title) toggle should expose its row title to accessibility")
    }
    try expectEqual(
      try label("accessibility-permission", in: controller.view).stringValue,
      "Required",
      "permission label should reflect missing accessibility")
    _ = try expectNotNil(
      findSubview(identifier: "request-access", in: controller.view) as NSButton?,
      "request access button should be visible when permission is missing")
  },

  TestCase(
    behavior: "given user changes settings then runtime persists configuration"
  ) {
    let driver = SettingsRuntimeDriver(
      configuration: .defaultValue,
      accessibilityTrusted: true
    )
    let runtime = ProboRuntime(environment: driver.environment)
    runtime.refreshSystemState()

    let controller = ProboSettingsViewController(runtime: runtime)
    controller.loadView()

    let wheelStep = try popup("wheel-step", in: controller.view)
    wheelStep.selectItem(withTitle: "Medium")
    _ = NSApp.sendAction(wheelStep.action!, to: wheelStep.target, from: wheelStep)

    try expectEqual(
      driver.savedConfigurations.last?.intensity,
      .medium,
      "wheel step change should persist selected intensity")

    let optionPrecision = try button("option-precision", in: controller.view)
    optionPrecision.state = .on
    _ = NSApp.sendAction(optionPrecision.action!, to: optionPrecision.target, from: optionPrecision)

    try expectEqual(
      driver.savedConfigurations.last?.isOptionPrecisionEnabled,
      true,
      "toggle change should persist enabled state")
  },

  TestCase(
    behavior: "given accessibility is granted then settings removes request access button"
  ) {
    let driver = SettingsRuntimeDriver(
      configuration: .defaultValue,
      accessibilityTrusted: false
    )
    let runtime = ProboRuntime(environment: driver.environment)
    runtime.refreshSystemState()

    let controller = ProboSettingsViewController(runtime: runtime)
    controller.loadView()

    driver.accessibilityTrusted = true
    runtime.refreshSystemState()
    controller.reload()

    try expectEqual(
      try label("accessibility-permission", in: controller.view).stringValue,
      "Granted",
      "permission label should refresh after trust is granted")
    try expectNil(
      findSubview(identifier: "request-access", in: controller.view) as NSButton?,
      "request access button should be removed when permission is granted")
  },

  TestCase(
    behavior: "given settings reloads then window frame stays fixed"
  ) {
    let driver = SettingsRuntimeDriver(
      configuration: .defaultValue,
      accessibilityTrusted: false
    )
    let runtime = ProboRuntime(environment: driver.environment)
    runtime.refreshSystemState()

    let controller = ProboSettingsViewController(runtime: runtime)
    let window = NSWindow(contentViewController: controller)
    let frame = NSRect(x: 120, y: 160, width: 420, height: 320)
    window.setFrame(frame, display: false)

    driver.accessibilityTrusted = true
    runtime.refreshSystemState()
    controller.reload()

    try expectEqual(
      window.frame,
      frame,
      "settings reload should not resize or move the window")
  },
]

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
      startEventTap: { _ in },
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
  try expectNotNil(
    findSubview(identifier: identifier, in: view) as NSButton?,
    "expected button \(identifier)")
}

@MainActor
private func popup(_ identifier: String, in view: NSView) throws -> NSPopUpButton {
  try expectNotNil(
    findSubview(identifier: identifier, in: view) as NSPopUpButton?,
    "expected popup \(identifier)")
}

@MainActor
private func label(_ identifier: String, in view: NSView) throws -> NSTextField {
  try expectNotNil(
    findSubview(identifier: identifier, in: view) as NSTextField?,
    "expected label \(identifier)")
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
