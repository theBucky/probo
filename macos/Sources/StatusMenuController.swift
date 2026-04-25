import AppKit

struct StatusMenuState: Equatable {
  var configuration: AppConfiguration
  var startAtLoginEnabled: Bool
  var accessibilityTrusted: Bool
  var tapStatus: EventTapController.Status
}

private final class PassThroughImageView: NSImageView {
  override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

private enum StatusSymbol: Equatable {
  case on, off, needsAccess

  var name: String {
    switch self {
    case .on: "computermouse.fill"
    case .off: "computermouse"
    case .needsAccess: "exclamationmark.triangle.fill"
    }
  }

  var accessibilityDescription: String {
    switch self {
    case .on: "probo on"
    case .off: "probo off"
    case .needsAccess: "probo needs accessibility access"
    }
  }
}

@MainActor
final class StatusMenuController: NSObject {
  var onToggleEnabled: (() -> Void)?
  var onSelectIntensity: ((ScrollIntensity) -> Void)?
  var onSelectStepMode: ((ScrollStepMode) -> Void)?
  var onToggleLookUp: (() -> Void)?
  var onTogglePrecisionScroll: (() -> Void)?
  var onToggleStartAtLogin: (() -> Void)?
  var onGrantAccessibilityAccess: (() -> Void)?
  var onQuit: (() -> Void)?

  private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
  private let menu = NSMenu()
  private let iconView = PassThroughImageView()
  private let accessibilityGroupSeparator = NSMenuItem.separator()

  private let enableItem = NSMenuItem(
    title: "Enable", action: #selector(toggleEnabled), keyEquivalent: "")
  private let intensityItem = NSMenuItem(title: "Intensity", action: nil, keyEquivalent: "")
  private let stepModeItem = NSMenuItem(title: "Mode", action: nil, keyEquivalent: "")
  private let miscItem = NSMenuItem(title: "Misc", action: nil, keyEquivalent: "")
  private let slowItem = NSMenuItem(title: "Slow", action: #selector(selectSlow), keyEquivalent: "")
  private let mediumItem = NSMenuItem(
    title: "Medium", action: #selector(selectMedium), keyEquivalent: "")
  private let classicStepItem = NSMenuItem(
    title: "Native", action: #selector(selectClassicStep), keyEquivalent: "")
  private let highFrequencyStepItem = NSMenuItem(
    title: "High Performance", action: #selector(selectHighFrequencyStep), keyEquivalent: "")
  private let lookUpItem = NSMenuItem(
    title: "Look Up", action: #selector(toggleLookUp), keyEquivalent: "")
  private let precisionScrollItem = NSMenuItem(
    title: "Precise Scrolling", action: #selector(togglePrecisionScroll), keyEquivalent: "")
  private let startAtLoginItem = NSMenuItem(
    title: "Start at Login", action: #selector(toggleStartAtLogin), keyEquivalent: "")
  private let grantAccessibilityItem = NSMenuItem(
    title: "Grant Accessibility Access", action: #selector(grantAccessibilityAccess),
    keyEquivalent: "")
  private let quitItem = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")

  private var currentSymbol: StatusSymbol?

  override init() {
    super.init()

    for item in [
      enableItem, slowItem, mediumItem, classicStepItem, highFrequencyStepItem, lookUpItem,
      precisionScrollItem, startAtLoginItem, grantAccessibilityItem, quitItem,
    ] {
      item.target = self
    }

    slowItem.attributedTitle = Self.makeAttributedTitle(
      title: slowItem.title, subtitle: "Just slow")
    mediumItem.attributedTitle = Self.makeAttributedTitle(
      title: mediumItem.title, subtitle: "Balanced steps, Windows-like feel")
    classicStepItem.attributedTitle = Self.makeAttributedTitle(
      title: classicStepItem.title, subtitle: "One native line event per wheel tick")
    highFrequencyStepItem.attributedTitle = Self.makeAttributedTitle(
      title: highFrequencyStepItem.title, subtitle: "Higher-frequency unit line events")
    lookUpItem.attributedTitle = Self.makeAttributedTitle(
      title: lookUpItem.title, subtitle: "Trigger Look Up with mouse button 4")
    precisionScrollItem.attributedTitle = Self.makeAttributedTitle(
      title: precisionScrollItem.title, subtitle: "Hold \u{2325} for slow, precise scrolling")

    let intensityMenu = NSMenu(title: "Intensity")
    intensityMenu.addItem(slowItem)
    intensityMenu.addItem(mediumItem)
    intensityItem.submenu = intensityMenu

    let stepModeMenu = NSMenu(title: "Mode")
    stepModeMenu.addItem(classicStepItem)
    stepModeMenu.addItem(highFrequencyStepItem)
    stepModeItem.submenu = stepModeMenu

    let miscMenu = NSMenu(title: "Misc")
    miscMenu.addItem(lookUpItem)
    miscMenu.addItem(precisionScrollItem)
    miscItem.submenu = miscMenu

    menu.addItem(enableItem)
    menu.addItem(.separator())
    menu.addItem(intensityItem)
    menu.addItem(stepModeItem)
    menu.addItem(miscItem)
    menu.addItem(.separator())
    menu.addItem(startAtLoginItem)
    menu.addItem(accessibilityGroupSeparator)
    menu.addItem(grantAccessibilityItem)
    menu.addItem(.separator())
    menu.addItem(quitItem)

    statusItem.menu = menu
    configureStatusButton()
  }

  private func configureStatusButton() {
    let button = statusItem.button!
    button.title = ""
    iconView.translatesAutoresizingMaskIntoConstraints = false
    iconView.symbolConfiguration = NSImage.SymbolConfiguration(scale: .large)
    button.addSubview(iconView)
    NSLayoutConstraint.activate([
      iconView.centerXAnchor.constraint(equalTo: button.centerXAnchor),
      iconView.centerYAnchor.constraint(equalTo: button.centerYAnchor),
    ])
  }

  func render(_ state: StatusMenuState) {
    enableItem.state = state.configuration.isEnabled ? .on : .off
    slowItem.state = state.configuration.intensity == .slow ? .on : .off
    mediumItem.state = state.configuration.intensity == .medium ? .on : .off
    classicStepItem.state = state.configuration.stepMode == .classic ? .on : .off
    highFrequencyStepItem.state = state.configuration.stepMode == .highFrequency ? .on : .off
    lookUpItem.state = state.configuration.isLookUpEnabled ? .on : .off
    precisionScrollItem.state = state.configuration.isPrecisionScrollEnabled ? .on : .off
    startAtLoginItem.state = state.startAtLoginEnabled ? .on : .off
    accessibilityGroupSeparator.isHidden = state.accessibilityTrusted
    grantAccessibilityItem.isHidden = state.accessibilityTrusted

    applySymbol(symbol(for: state))
  }

  private func applySymbol(_ symbol: StatusSymbol) {
    guard currentSymbol != symbol else { return }
    let image = NSImage(
      systemSymbolName: symbol.name,
      accessibilityDescription: symbol.accessibilityDescription)!
    image.isTemplate = true
    if currentSymbol == nil {
      iconView.image = image
    } else {
      iconView.setSymbolImage(image, contentTransition: .replace.magic(fallback: .downUp))
    }
    currentSymbol = symbol
  }

  private func symbol(for state: StatusMenuState) -> StatusSymbol {
    if !state.accessibilityTrusted { return .needsAccess }
    if state.configuration.isEnabled && state.tapStatus.isEnabled { return .on }
    return .off
  }

  private static func makeAttributedTitle(title: String, subtitle: String) -> NSAttributedString {
    let paragraph = NSMutableParagraphStyle()
    paragraph.lineSpacing = 2
    paragraph.firstLineHeadIndent = 6
    paragraph.headIndent = 6
    let result = NSMutableAttributedString(
      string: title,
      attributes: [
        .font: NSFont.menuFont(ofSize: 0),
        .paragraphStyle: paragraph,
      ])
    result.append(
      NSAttributedString(
        string: "\n" + subtitle,
        attributes: [
          .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
          .foregroundColor: NSColor.secondaryLabelColor,
          .paragraphStyle: paragraph,
        ]))
    return result
  }

  @objc private func toggleEnabled() { onToggleEnabled?() }
  @objc private func selectSlow() { onSelectIntensity?(.slow) }
  @objc private func selectMedium() { onSelectIntensity?(.medium) }
  @objc private func selectClassicStep() { onSelectStepMode?(.classic) }
  @objc private func selectHighFrequencyStep() { onSelectStepMode?(.highFrequency) }
  @objc private func toggleLookUp() { onToggleLookUp?() }
  @objc private func togglePrecisionScroll() { onTogglePrecisionScroll?() }
  @objc private func toggleStartAtLogin() { onToggleStartAtLogin?() }
  @objc private func grantAccessibilityAccess() { onGrantAccessibilityAccess?() }
  @objc private func quit() { onQuit?() }
}
