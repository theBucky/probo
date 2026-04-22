import AppKit
import Foundation

struct StatusMenuState: Equatable {
    var configuration: AppConfiguration
    var startAtLoginEnabled: Bool
    var accessibilityTrusted: Bool
    var tapStatus: EventTapController.Status
}

final class StatusMenuController: NSObject {
    var onToggleEnabled: (() -> Void)?
    var onSelectIntensity: ((ScrollIntensity) -> Void)?
    var onToggleStartAtLogin: (() -> Void)?
    var onGrantAccessibilityAccess: (() -> Void)?
    var onQuit: (() -> Void)?

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let menu = NSMenu()

    private let enabledItem = NSMenuItem(title: "enabled", action: #selector(toggleEnabled), keyEquivalent: "")
    private let intensityItem = NSMenuItem(title: "intensity", action: nil, keyEquivalent: "")
    private let slowItem = NSMenuItem(title: "slow", action: #selector(selectSlow), keyEquivalent: "")
    private let mediumItem = NSMenuItem(title: "medium", action: #selector(selectMedium), keyEquivalent: "")
    private let startAtLoginItem = NSMenuItem(title: "start at login", action: #selector(toggleStartAtLogin), keyEquivalent: "")
    private let grantAccessibilityItem = NSMenuItem(title: "grant accessibility access", action: #selector(grantAccessibilityAccess), keyEquivalent: "")
    private let quitItem = NSMenuItem(title: "quit", action: #selector(quit), keyEquivalent: "q")

    override init() {
        super.init()

        [enabledItem, slowItem, mediumItem, startAtLoginItem, grantAccessibilityItem, quitItem]
            .forEach { $0.target = self }

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
        statusItem.button?.title = "probo"
    }

    func render(_ state: StatusMenuState) {
        enabledItem.state = state.configuration.isEnabled ? .on : .off
        slowItem.state = state.configuration.intensity == .slow ? .on : .off
        mediumItem.state = state.configuration.intensity == .medium ? .on : .off
        startAtLoginItem.state = state.startAtLoginEnabled ? .on : .off
        grantAccessibilityItem.isHidden = state.accessibilityTrusted

        if !state.accessibilityTrusted {
            statusItem.button?.title = "probo!"
        } else if state.configuration.isEnabled && state.tapStatus.isEnabled {
            statusItem.button?.title = "probo"
        } else {
            statusItem.button?.title = "probo off"
        }
    }

    @objc private func toggleEnabled() {
        onToggleEnabled?()
    }

    @objc private func selectSlow() {
        onSelectIntensity?(.slow)
    }

    @objc private func selectMedium() {
        onSelectIntensity?(.medium)
    }

    @objc private func toggleStartAtLogin() {
        onToggleStartAtLogin?()
    }

    @objc private func grantAccessibilityAccess() {
        onGrantAccessibilityAccess?()
    }

    @objc private func quit() {
        onQuit?()
    }
}
