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

private struct SymbolSpec: Equatable {
    let name: String
    let description: String

    static let on = SymbolSpec(name: "computermouse.fill", description: "probo on")
    static let off = SymbolSpec(name: "computermouse", description: "probo off")
    static let needsAccess = SymbolSpec(name: "exclamationmark.triangle.fill", description: "probo needs accessibility access")
}

@MainActor
final class StatusMenuController: NSObject {
    var onToggleEnabled: (() -> Void)?
    var onSelectIntensity: ((ScrollIntensity) -> Void)?
    var onToggleStartAtLogin: (() -> Void)?
    var onGrantAccessibilityAccess: (() -> Void)?
    var onQuit: (() -> Void)?

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let menu = NSMenu()
    private let iconView = PassThroughImageView()

    private let enabledItem = NSMenuItem(title: "enabled", action: #selector(toggleEnabled), keyEquivalent: "")
    private let intensityItem = NSMenuItem(title: "intensity", action: nil, keyEquivalent: "")
    private let slowItem = NSMenuItem(title: "slow", action: #selector(selectSlow), keyEquivalent: "")
    private let mediumItem = NSMenuItem(title: "medium", action: #selector(selectMedium), keyEquivalent: "")
    private let startAtLoginItem = NSMenuItem(title: "start at login", action: #selector(toggleStartAtLogin), keyEquivalent: "")
    private let grantAccessibilityItem = NSMenuItem(title: "grant accessibility access", action: #selector(grantAccessibilityAccess), keyEquivalent: "")
    private let quitItem = NSMenuItem(title: "quit", action: #selector(quit), keyEquivalent: "q")

    private var currentSpec: SymbolSpec?

    override init() {
        super.init()

        for item in [enabledItem, slowItem, mediumItem, startAtLoginItem, grantAccessibilityItem, quitItem] {
            item.target = self
        }

        let intensityMenu = NSMenu(title: "intensity")
        intensityMenu.addItem(slowItem)
        intensityMenu.addItem(mediumItem)
        intensityItem.submenu = intensityMenu

        menu.addItem(enabledItem)
        menu.addItem(intensityItem)
        menu.addItem(startAtLoginItem)
        menu.addItem(.separator())
        menu.addItem(grantAccessibilityItem)
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
        enabledItem.state = state.configuration.isEnabled ? .on : .off
        slowItem.state = state.configuration.intensity == .slow ? .on : .off
        mediumItem.state = state.configuration.intensity == .medium ? .on : .off
        startAtLoginItem.state = state.startAtLoginEnabled ? .on : .off
        grantAccessibilityItem.isHidden = state.accessibilityTrusted

        applySymbol(symbolSpec(for: state))
    }

    private func applySymbol(_ spec: SymbolSpec) {
        guard currentSpec != spec else { return }
        let image = NSImage(systemSymbolName: spec.name, accessibilityDescription: spec.description)!
        image.isTemplate = true
        if currentSpec == nil {
            iconView.image = image
        } else {
            iconView.setSymbolImage(image, contentTransition: .replace.magic(fallback: .downUp))
        }
        currentSpec = spec
    }

    private func symbolSpec(for state: StatusMenuState) -> SymbolSpec {
        if !state.accessibilityTrusted { return .needsAccess }
        if state.configuration.isEnabled && state.tapStatus.isEnabled { return .on }
        return .off
    }

    @objc private func toggleEnabled() { onToggleEnabled?() }
    @objc private func selectSlow() { onSelectIntensity?(.slow) }
    @objc private func selectMedium() { onSelectIntensity?(.medium) }
    @objc private func toggleStartAtLogin() { onToggleStartAtLogin?() }
    @objc private func grantAccessibilityAccess() { onGrantAccessibilityAccess?() }
    @objc private func quit() { onQuit?() }
}
