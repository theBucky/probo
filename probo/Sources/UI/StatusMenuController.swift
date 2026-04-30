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
  var onShowSettings: (() -> Void)?
  var onToggleEnabled: (() -> Void)?
  var onToggleStartAtLogin: (() -> Void)?
  var onQuit: (() -> Void)?

  private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
  private let menu = NSMenu()
  private let iconView = PassThroughImageView()

  private let enableItem = NSMenuItem(
    title: "Enable", action: #selector(toggleEnabled), keyEquivalent: "")
  private let startAtLoginItem = NSMenuItem(
    title: "Start at Login", action: #selector(toggleStartAtLogin), keyEquivalent: "")
  private let quitItem = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")

  private var currentSymbol: StatusSymbol?

  override init() {
    super.init()

    for item in [
      enableItem, startAtLoginItem, quitItem,
    ] {
      item.target = self
    }

    menu.addItem(enableItem)
    menu.addItem(.separator())
    menu.addItem(startAtLoginItem)
    menu.addItem(.separator())
    menu.addItem(quitItem)

    configureStatusButton()
  }

  private func configureStatusButton() {
    let button = statusItem.button!
    button.title = ""
    button.target = self
    button.action = #selector(statusButtonPressed)
    button.sendAction(on: [.leftMouseUp, .rightMouseUp])
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
    startAtLoginItem.state = state.startAtLoginEnabled ? .on : .off

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

  @objc private func statusButtonPressed() {
    guard let event = NSApp.currentEvent else {
      onShowSettings?()
      return
    }

    if event.type == .rightMouseUp || event.modifierFlags.contains(.control) {
      let button = statusItem.button!
      menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.minY), in: button)
      return
    }

    onShowSettings?()
  }

  @objc private func toggleEnabled() { onToggleEnabled?() }
  @objc private func toggleStartAtLogin() { onToggleStartAtLogin?() }
  @objc private func quit() { onQuit?() }
}
